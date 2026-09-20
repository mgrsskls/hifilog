"""Read a product page that states nothing in machine readable form.

Most hi-fi brands are small, and a small brand has a hand built site. There is
no schema.org object, the specification is a table or a list of sentences, and
the model number is only in the heading. A language model reads these pages
well. It also invents values when it is asked in the wrong way, and an invented
specification is worse for hifilog than an empty one.

Four rules keep it honest. They are in the prompt, and three of them are also
enforced in code after the answer comes back, because a prompt is a request and
a check is a guarantee.

  1. The model may only write fields that this catalogue has. The field list is
     built from the schema export, so a sub category that does not exist and an
     attribute option that is not offered cannot be returned at all.
  2. Every field is optional and the default is null. The prompt says that an
     empty field is the correct answer when the page does not state the value,
     and that a value from general knowledge is a fault.
  3. Every value must come with the words from the page that state it. The
     quotation is checked against the page text. A value whose quotation is not
     in the text is dropped, which removes most invented values without a
     second call.
  4. The page is one product or it is not a product at all. A list page returns
     is_product false rather than a guess at which of the twelve products on it
     is the subject.
"""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.request
from typing import Any, Dict, List, Optional

from .candidates import Candidate, Provenance
from .normalize import looks_like_model, parse_price, parse_year

API_URL = "https://api.anthropic.com/v1/messages"
# The model ids change over time, so this is one constant and an
# environment variable rather than a name spread through the code.
# HIFILOG_IMPORT_MODEL overrides it: claude-haiku-4-5-20251001 is the
# cheaper choice for short work like classifying a product name.
MODEL = os.environ.get("HIFILOG_IMPORT_MODEL", "claude-sonnet-5")

PROMPT = """You read one product page from the website of the hi-fi manufacturer \
"{brand}" and write down only what the page states.

Rules, in order of importance:
1. Write a field only if this page states it. If the page does not state it, \
leave the field out. An empty field is correct and expected. A value from your \
own knowledge of this product is a fault, even if you are sure it is right.
2. For every field you write, put the exact words from the page that state it \
into "evidence". Copy them, do not rewrite them. A field without evidence is \
dropped.
3. The page must be about exactly one product. A category page, a list of \
products, a news article, a dealer page or a manual is not a product page: set \
"is_product" to false and write nothing else.
4. Use only the sub category slugs and option keys given below. If none fits, \
leave the field out.

This catalogue is for home hi-fi. Studio, PA, live sound, cinema, instrument \
and car audio equipment is out of scope: set "is_product" to false for those.

Sub categories:
{sub_categories}

Attributes that apply, by sub category:
{attributes}

The price is the list price that the page states, with its currency. Ignore a \
discounted price, a price for an accessory and a price with "from" in front of \
it unless there is no other.

The page:
---
{page}
---

Answer with one JSON object and nothing else:
{{"is_product": true|false, "name": ..., "model_no": ..., \
"sub_category_slug": ..., "price": ..., \
"price_currency": ..., "release_year": ..., "discontinued": true|false, \
"attributes": {{"<label>": <value>}}, \
"evidence": {{"<field name>": "<the words from the page>"}}}}
"""


class Schema:
    """The importable shape of a product, as the catalogue defines it."""

    def __init__(self, data: dict):
        self.sub_categories = data.get("sub_categories", [])
        self.custom_attributes = data.get("custom_attributes", [])

    @classmethod
    def load(cls, path) -> "Schema":
        with open(path, "r", encoding="utf-8") as handle:
            return cls(json.load(handle))

    @property
    def sub_category_slugs(self) -> List[str]:
        return [item["slug"] for item in self.sub_categories]

    def describe_sub_categories(self) -> str:
        return "\n".join(
            f"- {item['slug']}: {item['name']} ({item['category']})"
            for item in self.sub_categories
        )

    def describe_attributes(self) -> str:
        lines = []
        for attribute in self.custom_attributes:
            scope = ", ".join(attribute.get("sub_categories", [])) or "all"
            line = f"- {attribute['label']} ({attribute.get('name', '')}) [{scope}]"
            if attribute.get("input_type") == "number":
                units = "/".join(attribute.get("units") or [])
                inputs = ", ".join(attribute.get("inputs") or [])
                line += f" number in {units}"
                if inputs:
                    line += f", one value per: {inputs}"
            options = attribute.get("options") or {}
            if options:
                keys = ", ".join(
                    value["key"] if isinstance(value, dict) else str(value)
                    for value in options.values()
                )
                many = attribute.get("input_type") == "options"
                line += f" {'list of' if many else 'one of'}: {keys}"
            lines.append(line)
        return "\n".join(lines)

    def attribute(self, label: str) -> Optional[dict]:
        for attribute in self.custom_attributes:
            if attribute["label"] == label:
                return attribute
        return None


def build_prompt(brand: str, page: str, schema: Schema) -> str:
    return PROMPT.format(
        brand=brand,
        sub_categories=schema.describe_sub_categories(),
        attributes=schema.describe_attributes(),
        page=page,
    )



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


def call_model(prompt: str, api_key: Optional[str] = None, timeout: int = 120) -> dict:
    key = api_key or os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        raise RuntimeError("ANTHROPIC_API_KEY is not set")
    body = json.dumps(
        {
            "model": MODEL,
            "max_tokens": 2000,
            # Zero temperature, because the same page must give the same answer.
            # A re-run that gives other values makes it impossible to see
            # whether a change came from the site or from the extractor.
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
    return parse_answer(text)


def parse_answer(text: str) -> dict:
    """The JSON object out of the answer, whatever is written around it."""
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-z]*\n|```$", "", text).strip()
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        return {}
    try:
        return json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        return {}


def _evidence_in_page(evidence: Optional[str], page: str) -> bool:
    """True when the quoted words are really on the page.

    Compared without spaces and without case, because a page breaks a line
    where the answer does not. This is a check against an invented value, not a
    check of the value itself: a model that quotes the page correctly can still
    read the wrong number out of it.
    """
    if not evidence:
        return False
    reduce = lambda value: re.sub(r"\s+", "", value).lower()
    return reduce(evidence)[:120] in reduce(page)


def apply_text_extraction(
    candidate: Candidate,
    answer: dict,
    page: str,
    url: str,
    schema: Schema,
) -> bool:
    """Write the checked parts of an answer onto the candidate.

    Returns False when the page is not a product page, in which case the
    candidate must be thrown away rather than written to staging.
    """
    if not answer or answer.get("is_product") is False:
        return False

    evidence: Dict[str, Any] = answer.get("evidence") or {}

    def quoted(field_name: str) -> Optional[str]:
        value = evidence.get(field_name)
        return value if isinstance(value, str) else None

    def accept(field_name: str, value: Any) -> Optional[Provenance]:
        if value in (None, "", [], {}):
            return None
        words = quoted(field_name)
        if not _evidence_in_page(words, page):
            candidate.warnings.append(f"{field_name}: evidence not found on page")
            return None
        return Provenance("llm", url, words[:200])

    name = answer.get("name")
    source = accept("name", name)
    if source:
        candidate.set("name", str(name).strip(), source)

    model_no = answer.get("model_no")
    source = accept("model_no", model_no)
    if source and looks_like_model(str(model_no)):
        candidate.set("model_no", str(model_no).strip(), source)

    slug = answer.get("sub_category_slug")
    if slug in schema.sub_category_slugs:
        source = accept("sub_category_slug", slug) or Provenance("llm", url, "classified")
        candidate.set("sub_category_slug", slug, source)
    elif slug:
        candidate.warnings.append(f"unknown sub category {slug!r}")

    price = parse_price(answer.get("price"))
    source = accept("price", answer.get("price"))
    if price and source:
        candidate.set("price", price, source)
        currency = answer.get("price_currency")
        if currency:
            candidate.set("price_currency", str(currency).upper()[:3], source)

    year = parse_year(answer.get("release_year"))
    source = accept("release_year", answer.get("release_year"))
    if year and source:
        candidate.set("release_year", year, source)

    if answer.get("discontinued") is True:
        source = accept("discontinued", True)
        if source:
            candidate.set("discontinued", True, source)

    for label, value in (answer.get("attributes") or {}).items():
        definition = schema.attribute(label)
        if not definition:
            candidate.warnings.append(f"unknown attribute {label!r}")
            continue
        cleaned = _clean_attribute(definition, value)
        if cleaned is None:
            continue
        source = accept(label, value) or accept(f"attributes.{label}", value)
        if source:
            candidate.set_attribute(label, cleaned, source)

    return bool(candidate.name)


def _clean_attribute(definition: dict, value: Any) -> Any:
    """Keep an attribute value only in the shape the catalogue can store."""
    input_type = definition.get("input_type")
    options = definition.get("options") or {}
    keys_by_name = {
        (entry["key"] if isinstance(entry, dict) else str(entry)): option_id
        for option_id, entry in options.items()
    }

    if input_type in ("option", "options"):
        values = value if isinstance(value, list) else [value]
        ids = [keys_by_name[str(item)] for item in values if str(item) in keys_by_name]
        if not ids:
            return None
        return ids if input_type == "options" else ids[0]

    if input_type == "boolean":
        return bool(value) if isinstance(value, bool) else None

    if input_type == "number":
        unit = (definition.get("units") or [None])[0]
        inputs = definition.get("inputs") or []
        if inputs and isinstance(value, dict):
            numbers = {
                key: parse_price(item)
                for key, item in value.items()
                if key in inputs and parse_price(item) is not None
            }
            return {"value": numbers, "unit": unit} if numbers else None
        number = parse_price(value)
        return {"value": number, "unit": unit} if number is not None else None

    return None
