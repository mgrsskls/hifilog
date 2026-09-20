"""Make two spellings of one product into one key.

The catalogue already has a unique index on (brand_id, model_no), which is the
right rule. The difficulty is that a brand writes the same model number in four
ways across its own site: "CXA81 MkII", "CXA-81 Mk2", "cxa81mkii", "CXA81MKII".
If the importer does not decide that these are one product, the review queue
shows the same thing four times, and an unattended import creates four rows.

The key is therefore built from a reduced form: upper case, no punctuation, no
spaces, and the common revision words written one way. The reduced form is used
only for comparison. What is written to the catalogue is always the spelling
that the brand used.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Optional

# Roman numerals after a revision word, longest first. A word boundary cannot be
# used: "cxa81mkii" is written without spaces, and that spelling is exactly the
# one that must reduce to the same key as "CXA81 MkII".
ROMAN = (
    ("VIII", "8"), ("VII", "7"), ("III", "3"), ("IV", "4"),
    ("VI", "6"), ("II", "2"), ("V", "5"), ("I", "1"),
)

# Words in a page title that are not part of the product name.
TITLE_NOISE = re.compile(
    r"\s*[|–—\-]\s*(buy|shop|official|home|hi-?fi|audio|store|"
    r"products?|kaufen|jetzt)\b.*$",
    re.I,
)


def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKD", value or "")
    value = value.encode("ascii", "ignore").decode()
    value = re.sub(r"[^a-zA-Z0-9]+", "-", value).strip("-").lower()
    return value


def reduce_model(value: Optional[str]) -> str:
    """The comparison form of a model number or a product name."""
    if not value:
        return ""
    text = unicodedata.normalize("NFKD", value)
    text = text.encode("ascii", "ignore").decode()
    text = text.upper()
    text = re.sub(r"\bMARK\s*", "MK", text)
    text = re.sub(r"[^A-Z0-9]", "", text)
    for numeral, digit in ROMAN:
        text = re.sub(r"MK" + numeral + r"(?![A-Z])", "MK" + digit, text)
    return text


def dedupe_key(brand_slug: str, model_no: Optional[str], name: Optional[str]) -> str:
    """One key for one product of one brand.

    The model number is used when there is one, because that is what the
    catalogue's unique index uses. The name is the fallback. A name that starts
    with the brand name has it removed first: "Rega Planar 3" and "Planar 3" on
    the same brand are one product.
    """
    reduced = reduce_model(model_no) or reduce_model(strip_brand(name, brand_slug))
    return f"{brand_slug}:{reduced}" if reduced else ""


def strip_brand(name: Optional[str], brand_slug: str) -> str:
    if not name:
        return ""
    brand_words = brand_slug.replace("-", " ")
    pattern = r"^\s*" + re.escape(brand_words) + r"\s+"
    return re.sub(pattern, "", name, flags=re.I).strip()


def clean_title(title: Optional[str], brand_name: Optional[str] = None) -> Optional[str]:
    """A page title reduced to a probable product name.

    A title is the weakest of the sources for a name, and it is the one that is
    always there. It is used only when the markup gives nothing.
    """
    if not title:
        return None
    text = re.split(r"\s*[|–—]\s*", title.strip())[0]
    text = TITLE_NOISE.sub("", text).strip()
    if brand_name:
        text = strip_brand(text, slugify(brand_name)) or text
    return text or None


def looks_like_model(value: Optional[str]) -> bool:
    """True when a string has the shape of a model number.

    A model number is short, and it nearly always mixes letters with digits.
    This keeps a sentence out of the model_no column, which is the mistake that
    a text extractor makes most often.
    """
    if not value:
        return False
    value = value.strip()
    if len(value) > 40 or " " in value.strip() and len(value.split()) > 4:
        return False
    return bool(re.search(r"\d", value)) and bool(re.search(r"[A-Za-z]", value))


def parse_price(value) -> Optional[float]:
    """Read a price that is written for people.

    Both separators are in use: "1.299,00" in Germany and "1,299.00" in the UK.
    The rule is that the last separator with two digits after it is the decimal
    separator, and everything else is a thousands separator.
    """
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = re.sub(r"[^\d.,]", "", str(value))
    if not text:
        return None
    match = re.search(r"[.,](\d{2})$", text)
    if match:
        separator = text[match.start()]
        text = text[: match.start()].replace(".", "").replace(",", "") + "." + match.group(1)
        del separator
    else:
        text = text.replace(".", "").replace(",", "")
    try:
        return float(text)
    except ValueError:
        return None


def parse_year(value) -> Optional[int]:
    """A four digit year, but only one that a hi-fi product can have."""
    if value is None:
        return None
    match = re.search(r"(1[89]\d{2}|20\d{2})", str(value))
    if not match:
        return None
    year = int(match.group(1))
    return year if 1920 <= year <= 2100 else None


# Words that describe one version of a product rather than the product. A brand
# writes them into the product name of its own markup: real examples are
# "CXA81 MKII Black UK/EU" and "Planar 3 Gloss White". The catalogue keeps the
# product and its versions apart -- products and product_variants -- so the two
# parts have to be separated before anything is written.
FINISHES = (
    "black", "white", "silver", "grey", "gray", "graphite", "titanium",
    "chrome", "gold", "bronze", "copper", "natural", "matt", "matte", "gloss",
    "satin", "piano", "lacquer", "walnut", "oak", "cherry", "rosewood",
    "mahogany", "ebony", "bamboo", "veneer", "lunar", "anthracite", "champagne",
    "red", "blue", "green", "beige", "cream", "ivory", "sand", "olive",
)
REGIONS = (
    "uk", "eu", "us", "usa", "au", "jp", "row", "ce", "uk/eu", "eu/uk",
    "110v", "115v", "120v", "220v", "230v", "240v", "100v",
)


def split_variant(name: Optional[str]) -> tuple:
    """Separate a product name from the version words at its end.

    Returns (product name, version name or None). Only a whole word at the end
    is removed, and only while the words are finish or region words: "Black
    Edition Two" keeps "Two", and a product whose name is only a colour keeps
    its name.
    """
    if not name:
        return name, None
    words = name.split()
    cut = len(words)
    while cut > 1:
        word = words[cut - 1].strip(",()").lower()
        if word in FINISHES or word in REGIONS or _is_region_pair(word):
            cut -= 1
            continue
        break
    if cut == len(words):
        return name.strip(), None
    return " ".join(words[:cut]).strip(" ,-"), " ".join(words[cut:]).strip(" ,-") or None


def _is_region_pair(word: str) -> bool:
    parts = re.split(r"[/|]", word)
    return len(parts) > 1 and all(part in REGIONS for part in parts if part)


# A shop sells the same product in states that a catalogue does not have: a
# demonstration unit, a returned unit, a bundle. The name says so, and the page
# is otherwise a normal product page with its own markup and its own price.
# These are not refused here, because a boutique brand sometimes sells only in
# this way, but they are marked so that a reviewer sees them at once.
SHOP_STATES = (
    "b-stock", "b stock", "open box", "open-box", "ex-demo", "ex demo",
    "demo unit", "show model", "refurbished", "pre-owned", "preowned",
    "second hand", "used", "clearance", "trade-in", "bundle", "gift card",
    "gift voucher", "deposit", "spare part", "replacement",
)


def shop_state(name: Optional[str]) -> Optional[str]:
    """The words in a product name that describe a sale, not a product."""
    if not name:
        return None
    lowered = name.lower()
    for state in SHOP_STATES:
        if state in lowered:
            return state
    return None


# Separators a site puts between a product name and its own name.
SITE_SEPARATORS = ("\u2014", "\u2013", "|", "-", "\u00b7", "::", ":")


def strip_site_suffix(name: Optional[str], brand_name: Optional[str]) -> Optional[str]:
    """Take the site's own name off the end of a product name.

    Squarespace writes the site title into the schema.org name of every product:
    all 277 products of the first sample came back as "<product> \u2014 <brand>".
    The brand is already known -- it is the row the candidate belongs to -- so
    the suffix carries nothing and would go into the catalogue as part of the
    name.

    Only a suffix that really is the brand is removed, compared in the reduced
    form, so "Planar 3 - Walnut" keeps its "Walnut" and a brand whose products
    are named after it ("Rega Planar 3") keeps its name intact.
    """
    if not name or not brand_name:
        return name
    wanted = reduce_model(brand_name)
    if not wanted:
        return name
    for separator in SITE_SEPARATORS:
        head, found, tail = name.rpartition(f" {separator} ")
        if found and reduce_model(tail) == wanted:
            return head.strip() or name
    return name


def sku_is_the_model(sku: Optional[str], name: Optional[str]) -> bool:
    """True when a shop's article number may be used as the model number.

    A shop's SKU is its own stock number, not the manufacturer's. Real examples
    from the first import: "WAUD-WA11-BK" for the Woo Audio WA11, "ADVR34-NVY"
    for the R34, "ADVXLR3F35M-BLK" for an XLR cable. Each carries a house
    prefix, and most carry the finish -- so two colours of one product would
    become two products, because `model_no` is unique per brand and each colour
    has its own number.

    The rule is therefore narrow: the article number is used only when it can
    be read in the product's own name. "CS55A" in "Cayin CS-55A" is the model.
    "WAUDWA11BK" is nowhere in "Woo Audio WA11 Topaz Headphone Amplifier", so it
    is not.

    The test is one-sided on purpose. A name inside the number ("R34" inside
    "ADVR34NVY") means the number has house decoration around the model, which
    is exactly the case to refuse.

    An empty model number costs a reviewer a few seconds. A wrong one is a wrong
    unique key, and the catalogue grows a second copy of the same product.
    """
    if not sku or not name:
        return False
    reduced_sku = reduce_model(sku)
    return bool(reduced_sku) and reduced_sku in reduce_model(name)
