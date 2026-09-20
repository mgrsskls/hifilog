"""Give a product its sub categories, by reading its name.

The shop's own word answers part of the catalogue and never the rest: 5694
candidates carry no category at all, and the biggest words that remain
("Speakers", "Accessories") name two things or five. What is left is a question
about one product -- "is this a bookshelf or a floorstander" -- and the only
thing that can answer it is the product itself.

Three rules keep this honest, and they are the same three that the page
extractor follows:

  1. Only slugs that this catalogue defines. The list comes from the schema
     export, so an answer naming anything else is dropped rather than stored.
  2. An empty answer is correct. A name like "Model One" or "Universal" says
     nothing, and "unsure" is worth far more than a guess that a reviewer then
     has to find and undo.
  3. Nothing is promoted by this. A slug written here is a proposal in the
     staging table; a person still approves the product.

The answer may name more than one, because a product can be more than one: the
Wisdom Audio SUB1 is a subwoofer and an in-wall loudspeaker.
"""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.request
from typing import Dict, List, Optional

API_URL = "https://api.anthropic.com/v1/messages"
# The model ids change over time, so this is one constant and an
# environment variable rather than a name spread through the code.
# HIFILOG_IMPORT_MODEL overrides it: claude-haiku-4-5-20251001 is the
# cheaper choice for short work like classifying a product name.
MODEL = os.environ.get("HIFILOG_IMPORT_MODEL", "claude-sonnet-5")

# Raise when a change here would give a different answer for the same product.
CLASSIFIER_VERSION = "2026-09-15.1"

PROMPT = """You put hi-fi products into the categories of one catalogue.

The catalogue is home hi-fi only. Studio, PA, live sound, cinema installation, \
car, marine and professional equipment is out of scope, and so is anything that \
is not equipment: records, gift cards, spare parts, cushions, grilles, \
brackets, cables sold as bulk metre goods, clothing.

Categories, by slug:
{categories}

Rules:
1. Use only the slugs above. Never invent one.
2. Answer with an empty list when the product does not clearly belong to one. \
A name that says nothing ("Model One", "Universal", "Add On") is an empty list, \
not a guess. An empty answer is a correct answer and costs nothing; a wrong one \
has to be found and undone by a person.
3. Name more than one when the product really is more than one. An in-wall \
subwoofer is ["subwoofers", "in-wall-loudspeakers"]. Do not name two because you \
cannot choose between them -- that is an empty list. A feature is not a second \
product: a DAC with a headphone output or a volume control is only ["dacs"] when \
the maker lists it and names it as a DAC. Add "headphone-amplifiers" only when \
the maker also calls it a headphone amplifier ("DAC Headphone Amp").
4. Judge the product, not the brand. A loudspeaker maker also sells stands.
5. "out_of_scope": true for equipment this catalogue does not hold (car audio, \
studio monitors, televisions, appliances) and for things that are not products.

The products, as "<id>. <brand> | <shop's own category> | <name>":
{products}

Answer with one JSON object and nothing else:
{{"results": [{{"id": <the id>, "slugs": ["<slug>", ...], "out_of_scope": true|false}}]}}
"""


def build_prompt(items: List[dict], slugs: List[dict]) -> str:
    categories = "\n".join(
        f"- {item['slug']}: {item['name']} ({item['category']})" for item in slugs
    )
    products = "\n".join(
        f"{index}. {item.get('brand') or '?'} | {item.get('source_category') or '-'} "
        f"| {item.get('name') or ''}"
        for index, item in enumerate(items)
    )
    return PROMPT.format(categories=categories, products=products)



def _post(request, timeout: int) -> dict:
    """Send the request, and on a refusal raise with the API's own words.

    urllib raises HTTPError with the body unread, so a caller sees only "HTTP
    Error 400: Bad Request" -- and the body is the part that says which field is
    wrong (a model name that does not exist, a field that is missing). Reading
    it turns an hour of guessing into one line.
    """
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        try:
            detail = error.read().decode("utf-8", "replace")[:600]
        except Exception:
            detail = ""
        raise RuntimeError(f"HTTP {error.code}: {detail or error.reason}") from None


def call_model(prompt: str, api_key: Optional[str] = None, timeout: int = 180) -> dict:
    key = api_key or os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        raise RuntimeError("ANTHROPIC_API_KEY is not set")
    body = json.dumps(
        {
            "model": MODEL,
            "max_tokens": 4000,
            # The same product must give the same answer, so that a second run
            # changes nothing and a difference means the data changed.
            "temperature": 0,
            "messages": [{"role": "user", "content": prompt}],
        }
    ).encode()
    request = urllib.request.Request(
        API_URL,
        data=body,
        headers={
            "content-type": "application/json",
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
        },
    )
    answer = _post(request, timeout)
    text = "".join(
        part.get("text", "") for part in answer.get("content", []) if part.get("type") == "text"
    )
    return {"answer": parse_answer(text), "usage": answer.get("usage", {})}


def parse_answer(text: str) -> dict:
    text = (text or "").strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-z]*\n|```$", "", text).strip()
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end <= start:
        return {}
    try:
        return json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        return {}


def clean_results(answer: dict, items: List[dict], known_slugs: set) -> Dict[int, dict]:
    """Keep only what the catalogue can hold, by position in the batch.

    An id that names no product of this batch, and a slug this catalogue does
    not define, are both dropped in silence -- they are the two ways a model
    answer goes wrong, and neither is worth writing.
    """
    out: Dict[int, dict] = {}
    for row in (answer or {}).get("results") or []:
        if not isinstance(row, dict):
            continue
        index = row.get("id")
        if not isinstance(index, int) or not 0 <= index < len(items):
            continue
        slugs = [slug for slug in (row.get("slugs") or []) if slug in known_slugs]
        out[index] = {
            "slugs": slugs,
            "out_of_scope": row.get("out_of_scope") is True,
        }
    return out


def cache_key(item: dict) -> str:
    """One key for one product, as it was, read by these rules."""
    import hashlib

    raw = "|".join(
        [
            str(item.get("brand_slug")),
            str(item.get("name")),
            str(item.get("source_category")),
            CLASSIFIER_VERSION,
            MODEL,
        ]
    )
    return hashlib.sha256(raw.encode()).hexdigest()
