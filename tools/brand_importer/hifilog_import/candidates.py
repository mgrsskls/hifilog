"""The record that the importer produces.

A candidate is not a product. It is a statement about a product, with a source
for each field. Nothing goes into the catalogue directly from here: a candidate
is written to the staging table, and a person or a rule decides.

Two ideas carry the whole design:

  * Provenance is per field, not per record. One page gives the name from the
    title, the price from the markup, and the power from a specification table.
    These have different reliability, and a review must be able to see which is
    which. It also makes a second crawl useful: if the value changes, you can
    see what it was, where it came from, and when.

  * A field that is not found stays empty. An empty field costs a review a few
    seconds. A wrong field costs the trust of the user who finds it, and you
    will not know which products are wrong.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from typing import Any, Dict, Optional

# How much the source can be trusted, before any check of the value itself.
SOURCE_CONFIDENCE = {
    "jsonld": 0.95,      # the site states the value in machine readable form
    "microdata": 0.9,
    "products_json": 0.95,  # the shop software itself
    "llm": 0.6,          # read out of the text of the page
    "url": 0.4,          # taken from the address
    "heuristic": 0.3,
}


@dataclass
class Provenance:
    source: str
    url: str
    snippet: str = ""
    confidence: float = 0.0

    def __post_init__(self) -> None:
        if not self.confidence:
            self.confidence = SOURCE_CONFIDENCE.get(self.source, 0.5)


# Fields that the importer never fills, even when a page states them. The
# description of a product in the catalogue is written by people. A shop's text
# is marketing copy, and an extractor's summary of it is not better.
NOT_TAKEN = frozenset({"description"})


@dataclass
class Candidate:
    brand_slug: str
    source_url: str
    name: Optional[str] = None
    model_no: Optional[str] = None
    # The version words that the brand wrote into the product name, if any:
    # "Black UK/EU". The catalogue stores this as a product_variant, never as
    # part of the product name.
    variant_name: Optional[str] = None
    sub_category_slug: Optional[str] = None
    price: Optional[float] = None
    price_currency: Optional[str] = None
    release_year: Optional[int] = None
    discontinued: Optional[bool] = None
    discontinued_year: Optional[int] = None
    diy_kit: Optional[bool] = None
    image_urls: list = field(default_factory=list)
    # What the shop calls this product, and how many versions it sells. Neither
    # is written to the catalogue: a shop category is the shop's own word, and a
    # version is a product_variant that the review decides on. Both are carried
    # so that the review, and later the classifier, can see them.
    source_category: Optional[str] = None
    variants: list = field(default_factory=list)
    custom_attributes: Dict[str, Any] = field(default_factory=dict)
    provenance: Dict[str, Provenance] = field(default_factory=dict)
    warnings: list = field(default_factory=list)

    def set(self, name: str, value: Any, provenance: Provenance) -> None:
        """Write a field, but never over a field from a better source.

        Extraction runs from the most reliable source to the least reliable
        one. Markup goes first, then the text of the page. Without this rule
        the last extractor to run would win, which is the wrong way round.
        """
        if value in (None, "", [], {}):
            return
        if name in NOT_TAKEN:
            return
        existing = self.provenance.get(name)
        if existing and existing.confidence >= provenance.confidence:
            return
        setattr(self, name, value)
        self.provenance[name] = provenance

    def set_attribute(self, label: str, value: Any, provenance: Provenance) -> None:
        if value in (None, "", [], {}):
            return
        key = f"custom_attributes.{label}"
        existing = self.provenance.get(key)
        if existing and existing.confidence >= provenance.confidence:
            return
        self.custom_attributes[label] = value
        self.provenance[key] = provenance

    @property
    def dedupe_key(self) -> str:
        from .normalize import dedupe_key

        return dedupe_key(self.brand_slug, self.model_no, self.name)

    @property
    def match_keys(self) -> list:
        """Every key under which this candidate may be the same as another.

        The model number is the catalogue's own unique key, but a site does not
        always give a model number, and what it gives is not always one: many
        shops write an internal article number into the schema.org `mpn` field.
        A candidate is therefore offered under both keys, and a staging row that
        shares either key with an existing one is a possible duplicate that the
        review must look at.
        """
        from .normalize import dedupe_key, reduce_model, strip_brand

        keys = []
        if self.model_no:
            keys.append(f"{self.brand_slug}:{reduce_model(self.model_no)}")
        if self.name:
            reduced = reduce_model(strip_brand(self.name, self.brand_slug))
            if reduced:
                keys.append(f"{self.brand_slug}:{reduced}")
        del dedupe_key
        return list(dict.fromkeys(keys))

    @property
    def score(self) -> float:
        """How complete and how well sourced this candidate is, from 0 to 1.

        The review queue is ordered by this. It is not a measure of truth: a
        candidate with a high score can still be wrong. It answers a different
        question, which is where a reviewer's next minute is best spent.
        """
        if not self.name:
            return 0.0
        weights = {
            "name": 3, "sub_category_slug": 3,
            "model_no": 2, "price": 1, "release_year": 1,
        }
        total = sum(weights.values())
        # A field with no provenance entry was written directly rather than by an
        # extractor. It counts, but at the lowest confidence: nothing says where
        # it came from.
        got = sum(
            weight * min(1.0, self.provenance[name].confidence if name in self.provenance else 0.3)
            for name, weight in weights.items()
            if getattr(self, name) not in (None, "", [], {})
        )
        return round(got / total, 3)

    def to_json(self) -> str:
        data = asdict(self)
        data["provenance"] = {
            name: asdict(entry) for name, entry in self.provenance.items()
        }
        data["dedupe_key"] = self.dedupe_key
        data["match_keys"] = self.match_keys
        data["score"] = self.score
        return json.dumps(data, ensure_ascii=False)
