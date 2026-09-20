"""What a shop sells that a hi-fi catalogue does not hold.

A brand's shop is not a product catalogue. Along with the amplifiers it sells
repair plans, gift cards, spare feet, T-shirts, records, and the same speaker
again as a returned unit at eighty percent. The first real run over 128 Shopify
shops produced 14792 items, and several thousand of them were of this kind.

Every one of them would otherwise reach the review queue, where a person has to
read the name and refuse it. That is the most expensive way to find out that a
gift card is not a loudspeaker.

The test is deliberately narrow. It reads the name and the shop's own category,
both of which the shop states plainly, and it refuses only what is clearly not
a product of this catalogue. Anything it is unsure about it lets through: a
false refusal hides a real product and nobody will notice, while a false pass
costs one second in the review.

Nothing is thrown away. The document store holds every answer, so a rule that
turns out to be wrong is corrected by running `extract` again.
"""

from __future__ import annotations

import re
from typing import Optional, Tuple

# Each rule is a reason and the words that mean it. The words are matched as
# whole words in the product name or in the shop's own category.
RULES: Tuple[Tuple[str, Tuple[str, ...]], ...] = (
    (
        "a service, not a product",
        ("repair", "service plan", "care plan", "warranty", "insurance",
         "extended cover", "calibration service", "installation", "consultation",
         "trade-in", "trade in", "restoration service", "servicing"),
    ),
    (
        "a payment, not a product",
        ("gift card", "gift certificate", "gift voucher", "deposit",
         "balance payment", "final payment", "subscription", "donation",
         "shipping", "surcharge", "upgrade fee"),
    ),
    (
        "a recording, not equipment",
        ("vinyl lp", "vinyl record", "cds / lps", "cd / lp", "lp record",
         "test record", "demonstration disc", "sacd disc"),
    ),
    (
        "merchandise, not equipment",
        ("t-shirt", "tshirt", "hoodie", "sweatshirt", "cap", "mug", "poster",
         "sticker", "tote bag", "keychain", "apparel", "merch"),
    ),
    (
        "a part, not a product",
        ("spare part", "replacement part", "replacement driver", "spare driver",
         "stylus brush", "dust cover", "user manual", "owners manual",
         "service manual", "screw set", "fuse", "spike kit", "grille cloth"),
    ),
)

# A product that the shop sells in a state the catalogue does not have. It is a
# real product, so this is reported apart from the rules above.
CONDITIONS = (
    "b-stock", "b stock", "bstock", "outlet", "refurbished", "refurb",
    "open box", "open-box", "ex-demo", "ex demo", "demo unit", "show model",
    "pre-owned", "preowned", "second hand", "used", "clearance", "scratch and dent",
    "stocksale", "stocksales", "stock sale", "factory renewed", "renewed",
    "c stock", "c-stock",
    # Japanese shops: "outlet item" and "used item".
    "アウトレット", "中古",
)


# Ranges that one brand builds for a place this catalogue does not cover.
#
# A hi-fi maker often has a car and marine division selling from the same shop,
# and no shop category separates them: "Subwoofer" is the word for the home
# model and for the one that goes under a car seat. The range name is what
# separates them, and the brand knows it -- Cerwin-Vega's Stroker, HED, VMAXX,
# RPM, XED and Mobile lines are car and marine; its SL, LA, XLS and E series are
# home. Earthquake is the same shape.
#
# Validating 430 classified candidates by hand, these two brands produced 15 of
# the 59 errors, every one of them a car product in a home category. This is the
# rule that removes them, and it is written per brand because a range name means
# nothing outside its brand.
# Brands left out of an import entirely, for now.
#
# Not a statement that the brand is out of scope -- that is what a whole-brand
# mapping in the catalogue is for, and it is permanent. This is a pause: a brand
# whose home and car ranges are too tangled to separate by rule yet, set aside
# so that it stops producing noise in the review. Take a slug out of this list
# and run `extract` again, and every product of that brand comes back from the
# stored pages without a second crawl.
BRANDS_IGNORED_FOR_NOW = {
    # Home and car audio from one shop, and the car ranges keep slipping past
    # the range rules below (RPM104SL, Vega Series). Revisit when there is time
    # to list its home ranges instead.
    "cerwin-vega",
}

# DJ gear is out of scope as well. Ortofon sells its DJ cartridges (Concorde
# MKII, Q.bert, Scratch, Nightclub, Digitrack) on the same shop as its hi-fi
# ones, under the same category "Phono Cartridges" (also OM Pro S). "Concorde Music" is a hi-fi
# cartridge, so the rule names "Concorde MKII", not "Concorde".
BRAND_RANGES_OUT_OF_SCOPE = {
    "cerwin-vega": {
        "car or marine audio": (
            "stroker", "hed", "vmaxx", "vmax", "rpm", "xed", "cvp", "btr", "smlo",
            "mobile", "marine", "line output converter", "wake tower",
        ),
    },
    "earthquake": {
        "car or marine audio": (
            "sws", "marine", "under-the-seat", "under the seat", "mobile", "tnt",
            "tremor",
        ),
        "DJ gear": ("dj",),
    },
    "grado-labs": {
        "DJ gear": ("dj200i", "dj200"),
    },
    "ortofon": {
        "DJ gear": (
            "concorde mkii", "concorde mk ii", "concorde mk2", "cc mkii", "q.bert",
            "qbert", "scratch", "nightclub", "night club", "digitrack", "dj", "pro s",
            "vnl",
        ),
    },
}


def brand_range_out_of_scope(brand_slug: Optional[str], name: Optional[str],
                             category: Optional[str] = None) -> Optional[Tuple[str, str]]:
    """The range this product belongs to and what it is, when it is out of scope."""
    ranges = BRAND_RANGES_OUT_OF_SCOPE.get((brand_slug or "").lower())
    if not ranges:
        return None
    text = " ".join(part for part in (name, category) if part).lower()
    for kind, words in ranges.items():
        for word in words:
            if _contains(text, word):
                return word, kind
    return None


def _contains(haystack: str, needle: str) -> bool:
    """Whole word or whole phrase, so "used" does not match "unused"."""
    return re.search(r"(?<![a-z0-9])" + re.escape(needle) + r"(?![a-z0-9])", haystack) is not None


def out_of_scope(name: Optional[str], category: Optional[str] = None,
                 url: Optional[str] = None, brand_slug: Optional[str] = None) -> Optional[str]:
    """Why this is not a product for the catalogue, or None when it may be one.

    The address is read as well as the name, because a shop does not always say
    it twice: one Wix shop lists a ten percent deposit under the product's own
    name, "ZMC2", at /product-page/10-deposit-zmc2. Only the last part of the
    path is read, and with its hyphens as spaces, so that a domain or a folder
    cannot refuse a product by accident.
    """
    parts = [name, category]
    if url:
        slug = re.sub(r"[?#].*$", "", url).rstrip("/").rsplit("/", 1)[-1]
        parts.append(slug.replace("-", " ").replace("_", " "))
    text = " ".join(part for part in parts if part).lower()
    if not text.strip():
        return None
    if (brand_slug or "").lower() in BRANDS_IGNORED_FOR_NOW:
        return "brand set aside for now"
    found = brand_range_out_of_scope(brand_slug, name, category)
    if found:
        return f"the {found[0]} range is {found[1]}"
    for reason, words in RULES:
        if any(_contains(text, word) for word in words):
            return reason
    return None


# Brand names that are also ordinary words, and that a brand uses for its own
# ranges: Wireworld's Eclipse cable, Meze's Dual cable, Nakamichi's Opera, PS
# Audio's Sovereign. A product name that starts with one of these words is not
# read as the product of that other brand.
AMBIGUOUS_BRAND_NAMES = {
    "atlas", "axiom", "coda", "dual", "eclipse", "energy", "infinity", "integra",
    "mission", "opera", "outlaw", "sovereign", "tangent",
    # Compared without spaces: "Art Loudspeakers" reads as "art", and
    # "Pro-Ject" as "project", which is also Furutech's "Project V1" cable.
    "art", "project",
}

# Words that do not identify a brand on their own. A brand name made only of
# these (for example "Ø Audio", which reads as "audio") is never matched.
GENERIC_NAME_WORDS = {
    "audio", "hifi", "hi", "fi", "sound", "sounds", "acoustic", "acoustics",
    "cable", "cables", "labs", "lab", "the", "system", "systems",
}


def _words(text: Optional[str]) -> Tuple[str, ...]:
    return tuple(re.sub(r"[^a-z0-9]+", " ", (text or "").lower()).split())


class OtherBrands:
    """Find a product that a shop sells for another brand.

    Many brands also run a shop, and a shop sells more than its own products:
    Summit Hi-Fi sells NAD and SVS, Audio Art Cable sells Rega and Michell. The
    shop names such a product with the other brand first ("NAD C 558"). The
    pipeline stores every product of a site under the brand of the site, so
    this product would enter the catalogue under the wrong brand. It is not
    written at all. The other brand gets the product from its own site.

    The index holds every brand of the catalogue, keyed by the first word of
    its name, so that one test costs one dictionary look-up.
    """

    def __init__(self, brands) -> None:
        self.names: dict = {}
        self.by_joined_name: dict = {}
        for slug, name in brands:
            words = _words(name)
            self.names[slug] = words
            for form in _name_forms(words):
                self.by_joined_name.setdefault("".join(form), []).append((form, slug))

    def of(self, name: Optional[str], brand_slug: Optional[str]) -> Optional[str]:
        """The slug of the other brand that the name starts with, or None.

        The words are compared without the spaces between them, so that the
        shop's "TONE WINNER" finds the brand "ToneWinner". A name has at most
        a few words, so this is a few dictionary look-ups.
        """
        words = _words(name)
        if not words:
            return None
        own = self.names.get(brand_slug or "", ())
        for count in range(1, min(len(words), MAX_BRAND_WORDS) + 1):
            for brand_words, slug in self.by_joined_name.get("".join(words[:count]), ()):
                if slug == brand_slug:
                    continue
                # One brand name that starts the other: "Moon" and "Moon by Simaudio".
                if own and (own[:len(brand_words)] == brand_words or brand_words[:len(own)] == own):
                    continue
                # A product of two brands, "Denon x Ojas DL-103O" or "Klipsch/Ojas
                # kO-R1", stays with the brand whose site sells it.
                if own and _starts_within(words, own, count + 2):
                    continue
                return slug
        return None


# The longest brand name that is compared, in words.
MAX_BRAND_WORDS = 5

# A last word that some brands add to their name and that shops leave off:
# "PSB Speakers" sells as "PSB B600".
DROPPABLE_LAST_WORDS = {"speakers", "loudspeakers"}


def _name_forms(words: Tuple[str, ...]):
    """The forms of a brand name that a shop writes at the start of a product name."""
    forms = [words]
    if len(words) > 1 and words[-1] in DROPPABLE_LAST_WORDS:
        forms.append(words[:-1])
    for form in forms:
        if not form or len(form) > MAX_BRAND_WORDS:
            continue
        if all(word in GENERIC_NAME_WORDS for word in form):
            continue
        if "".join(form) in AMBIGUOUS_BRAND_NAMES or (len(form) == 1 and len(form[0]) < 3):
            continue
        yield form


def _starts_within(words: Tuple[str, ...], part: Tuple[str, ...], limit: int) -> bool:
    """True when `part` starts at one of the first `limit` positions of `words`."""
    for start in range(1, min(limit, len(words)) + 1):
        if words[start:start + len(part)] == part:
            return True
    return False


def condition(name: Optional[str], category: Optional[str] = None) -> Optional[str]:
    """The state a real product is sold in, when the shop names one."""
    text = " ".join(part for part in (name, category) if part).lower()
    for word in CONDITIONS:
        if _contains(text, word):
            return word
    return None
