"""A second reading of a classification, and what it decided.

Every sub category on a candidate is a proposal from something: a mapping
written by hand, or a classifier reading the product name. Neither checks
itself. This is the record of a second reading -- what was looked at, what it
decided, and who did the looking.

It lives in its own file rather than in `candidates.jsonl`, for one reason:
`extract` rewrites that file from the stored pages every time a rule changes,
and a check that a re-extract erases is worth nothing. The key is the product
rather than the row, so a check survives a re-crawl as well.

The verdicts:

  agreed        the categories are right; the row is marked as checked
  corrected     they were wrong; the right ones are written here
  classified    the row had no categories (no mapping answers its shop word);
                a first reading gives them here, the same way as `corrected`
  out_of_scope  the product does not belong in this catalogue at all
  no_category   the product belongs here, but the taxonomy has no place for it
  unsure        the reading could not tell; the row is marked, and the note
                says why, so a person looks at it first

A check of any verdict can also carry `corrected_name` and `corrected_variant`:
the product name as the catalogue should show it, when the shop's title holds
more than the name. The check's own `name` stays the shop's title, because the
key is made from it. The shop's title is kept on the row as `source_name`.

`no_category` is kept apart from the other two on purpose. "Out of scope" says
the product is wrong; "unsure" says the reading is. This one says the
*catalogue* is incomplete -- a tonearm cable is home hi-fi by any reading, and
there is no sub category for one. Those rows are the list to read when deciding
what the taxonomy is still missing, and lumping them in with the refusals would
hide exactly that.

A check is not an approval. A checked candidate is still a proposal, and a
person still decides.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Dict, Optional

VERDICTS = ("agreed", "corrected", "classified", "out_of_scope", "unsure", "no_category")


def key_for(brand_slug: str, name: str, source_category: Optional[str]) -> str:
    """One key for one product, so a check survives a re-extract and a re-crawl."""
    raw = f"{brand_slug}|{name}|{source_category or ''}"
    return hashlib.sha256(raw.encode()).hexdigest()


def load(path: Path) -> Dict[str, dict]:
    if not path.exists():
        return {}
    out: Dict[str, dict] = {}
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("key") and row.get("verdict") in VERDICTS:
                out[row["key"]] = row
    return out


def apply_to(candidate: dict, validation: dict) -> str:
    """Write one verdict onto one candidate. Returns what it did."""
    candidate["validated_at"] = validation.get("at")
    candidate["validated_by"] = validation.get("by")
    candidate["validation_note"] = validation.get("note")

    _rename(candidate, validation)

    verdict = validation["verdict"]
    # The verdict itself goes with the row. `rake import:load` rejects a row
    # read as out of scope, and `rake import:map` does not write over a row
    # whose verdict already decided its sub categories.
    candidate["validation_verdict"] = verdict
    if verdict in ("corrected", "classified") and validation.get("slugs"):
        candidate["sub_category_slugs"] = validation["slugs"]
        candidate.setdefault("provenance", {})["sub_category_slugs"] = {
            "source": "llm",
            "url": candidate.get("source_url", ""),
            "snippet": validation.get("note") or f"{verdict} by a reading of the name",
            "confidence": 0.7,
        }
    elif verdict == "no_category":
        # Not a refusal: the product belongs here and the catalogue has nowhere
        # to put it. The categories are cleared so nothing false is promoted,
        # and the note names what is missing.
        candidate["sub_category_slugs"] = []
        _warn(candidate, f"no sub category fits: {validation.get('note') or 'gap in the taxonomy'}")
    elif verdict == "out_of_scope":
        # The categories are removed rather than kept beside a warning: a
        # product that does not belong here must not arrive with a sub category
        # that would let it be promoted by a hurried click.
        candidate["sub_category_slugs"] = []
        _warn(candidate, f"read as out of scope: {validation.get('note') or 'not this catalogue'}")
    return verdict


def source_name(candidate: dict) -> str:
    """The name the shop wrote. A check is keyed by it, also after a rename."""
    return candidate.get("source_name") or candidate.get("name") or ""


def _rename(candidate: dict, validation: dict) -> None:
    """Write the name and the variant that a reading corrected.

    A shop writes more than the name into its product title: the brand, the
    kind of product, the pack size, a slogan ("F1-8 Standmount Speaker | Hi-Fi"
    is the F1-8). A check can give the name as the catalogue should show it,
    and the version words as the variant. The shop's own title is kept in
    `source_name`, because the key of the check is made from it: without it,
    the next run would not find the check again.
    """
    name = validation.get("corrected_name")
    if not name:
        return
    from .normalize import reduce_model, strip_brand

    candidate.setdefault("source_name", candidate.get("name"))
    candidate["name"] = name
    if "corrected_variant" in validation:
        candidate["variant_name"] = validation.get("corrected_variant")
    provenance = candidate.setdefault("provenance", {})
    provenance["name"] = {
        "source": "llm",
        "url": candidate.get("source_url", ""),
        "snippet": f"corrected from {candidate['source_name']!r}",
        "confidence": 0.7,
    }
    # The keys for the duplicate check are made from the name, so they are
    # made again. The key of the model number stays as it was.
    brand = candidate.get("brand_slug") or ""
    keys = [key for key in candidate.get("match_keys") or [] if not key.startswith(f"{brand}:")]
    if candidate.get("model_no"):
        keys.append(f"{brand}:{reduce_model(candidate['model_no'])}")
    reduced = reduce_model(strip_brand(name, brand))
    if reduced:
        keys.append(f"{brand}:{reduced}")
    candidate["match_keys"] = list(dict.fromkeys(keys))


def drop_model_equal_to_name(candidate: dict) -> bool:
    """Clear a model number that only repeats the product name.

    After the name is corrected, "F1-8" is often both the name and the model
    number. A model number that says nothing more than the name is left empty:
    the catalogue then shows the name once, and the unique index on the model
    number does not hold a copy of the name. The comparison ignores case,
    spaces and punctuation ("F1-8" and "f1 8" are the same). Returns True when
    the model number was cleared.
    """
    from .normalize import reduce_model

    model = candidate.get("model_no")
    name = candidate.get("name")
    if not model or not name or reduce_model(model) != reduce_model(name):
        return False
    candidate["model_no"] = None
    (candidate.get("provenance") or {}).pop("model_no", None)
    return True


import re

# A shop's category word that states the state of every product under it:
# "Discontinued models", "Archived Digital Cables", "Legacy Products",
# "Selection of Previously Sold Loudspeakers". "Legacy" counts only at the
# start or before "products" or "models", because it is also a series name
# (Jamo "Concert Legacy", the brand Legacy Audio).
DISCONTINUED_CATEGORY = re.compile(
    r"(?i)\b(discontinued|archived?|out of production|previously sold)\b"
    r"|^legacy\b(?!\s+audio)|\blegacy (products|models)\b"
)
# The same state, written into the product title by the shop:
# "DAC1 - Digital to Analog Audio Converter - Discontinued",
# "HX310 PEQ (DISCONTINUED)", "OYSTER – OUT OF PRODUCTION",
# "Prodigy 3B (Legacy)". Only at the end of the title, where it is a remark
# about the product and not a part of its name.
DISCONTINUED_TITLE = re.compile(
    r"(?i)(\s[-–—]\s*|\s*\()(discontinued|out of production|legacy)\)?\s*$"
)


def mark_discontinued(candidate: dict) -> bool:
    """Set `discontinued` when the shop's category or title states it.

    A shop that moved a product to its archive, or wrote "Discontinued" behind
    its name, has said the one thing that no availability field carries. The
    state is taken from the shop's own words, so it also holds after the name
    was corrected and the remark was taken out of it. Returns True when the
    state was set here.
    """
    if candidate.get("discontinued") is True:
        return False
    category = candidate.get("source_category") or ""
    title = source_name(candidate)
    if DISCONTINUED_CATEGORY.search(category):
        snippet = category
    elif DISCONTINUED_TITLE.search(title):
        snippet = title
    else:
        return False
    candidate["discontinued"] = True
    candidate.setdefault("provenance", {})["discontinued"] = {
        "source": "heuristic",
        "url": candidate.get("source_url", ""),
        "snippet": snippet,
        "confidence": 0.9,
    }
    return True


def _warn(candidate: dict, message: str) -> None:
    """Add a warning once. The command may be run again on the same file."""
    warnings = candidate.get("warnings") or []
    if message not in warnings:
        warnings.append(message)
    candidate["warnings"] = warnings
