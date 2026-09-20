"""Read what the page already states in machine readable form.

Many brand sites run on Shopify, WooCommerce or a similar system, and those
systems write a schema.org Product object into the page as JSON-LD. Where that
object exists it is better than anything a text extractor can do: the site
itself says which string is the name, which number is the price, and in which
currency. It costs nothing, it cannot hallucinate, and it is stable between
crawls.

Therefore this runs first, for every page. The text extractor runs only for the
fields that are still empty afterwards.

Note what is deliberately not done here. The JSON-LD `description` is not taken:
the description of a catalogue product is written by people, not copied from a
shop. And `category` is not taken as the hifilog sub category: a shop category
is a shop's own word ("Amplifiers", "New arrivals") and mapping it is a
decision, not a copy. The mapping happens in the classify step, where the list
of hifilog sub categories is known.
"""

from __future__ import annotations

import json
import re
from html.parser import HTMLParser
from typing import Any, Dict, Iterator, List, Optional

from .candidates import Candidate, Provenance
from .normalize import (
    clean_title,
    looks_like_model,
    parse_price,
    split_variant,
    sku_is_the_model,
    strip_site_suffix,
)

JSON_LD = re.compile(
    r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
    re.I | re.S,
)
TITLE = re.compile(r"<title[^>]*>(.*?)</title>", re.I | re.S)
META = re.compile(
    r'<meta[^>]+(?:property|name)=["\']([^"\']+)["\'][^>]+content=["\']([^"\']*)["\']',
    re.I,
)


def json_ld_objects(html: str) -> Iterator[dict]:
    """Every JSON-LD object in the page, with @graph and lists flattened."""
    for match in JSON_LD.finditer(html):
        raw = match.group(1).strip()
        # Some systems write more than one object in one script tag, or leave a
        # trailing comma. Do not try to repair anything else: a document that
        # does not parse is a document without markup, which is a case the text
        # extractor already handles.
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            try:
                data = json.loads(re.sub(r",\s*([}\]])", r"\1", raw))
            except json.JSONDecodeError:
                continue
        yield from _flatten(data)


def _flatten(data: Any) -> Iterator[dict]:
    if isinstance(data, list):
        for item in data:
            yield from _flatten(item)
    elif isinstance(data, dict):
        if "@graph" in data:
            yield from _flatten(data["@graph"])
        yield data


def _types(obj: dict) -> List[str]:
    value = obj.get("@type") or obj.get("type") or []
    values = value if isinstance(value, list) else [value]
    return [str(item).lower() for item in values]


def find_product(html: str) -> Optional[dict]:
    for obj in json_ld_objects(html):
        if "product" in _types(obj):
            return obj
    return None


def meta_tags(html: str) -> Dict[str, str]:
    return {name.lower(): content for name, content in META.findall(html)}


def apply_markup(
    candidate: Candidate, html: str, url: str, brand_name: Optional[str] = None
) -> bool:
    """Fill the candidate from the markup. True when a Product object was found."""
    product = find_product(html)
    meta = meta_tags(html)
    title_match = TITLE.search(html)

    if product:
        source = Provenance("jsonld", url, "schema.org/Product")
        # A brand writes the version into the name of its own markup, and one
        # page then carries several of them. The version words are taken off
        # here, so that the name is the name of the product.
        name, variant = split_variant(
            strip_site_suffix(_text(product.get("name")), brand_name)
        )
        candidate.set("name", name, source)
        candidate.set("variant_name", variant, source)
        offers = _offers(product)
        model = _text(product.get("mpn") or product.get("model") or product.get("sku"))
        trusted = bool(model)
        if not model and len(offers) == 1:
            # An article number on the only offer is the article number of the
            # product. With several offers each number belongs to one version --
            # one colour, one mains voltage -- and taking the first would put a
            # version's number on the product.
            model = _text(offers[0].get("sku") or offers[0].get("mpn"))
        if looks_like_model(model) and (trusted or sku_is_the_model(model, name)):
            candidate.set("model_no", model, source)
        images = _images(product)
        if images:
            candidate.set("image_urls", images, source)
        for offer in offers:
            price = parse_price(offer.get("price") or offer.get("lowPrice"))
            currency = offer.get("priceCurrency")
            # A price of zero is not a price. Shops write it for a product that
            # they no longer sell, and an empty currency comes with it.
            if not isinstance(currency, str) or not currency.strip():
                currency = None
            if price and price > 0:
                candidate.set("price", price, source)
                if currency:
                    candidate.set("price_currency", str(currency).upper(), source)
                break
        # Availability is a statement about a shop, not about a catalogue. It is
        # read only as a hint, and never as the discontinued flag: a product that
        # is out of stock today is not a discontinued product.
        for offer in offers:
            stated = availability_says_current(offer.get("availability"))
            if stated is not None:
                candidate.set(
                    "discontinued", stated,
                    Provenance("jsonld", url, str(offer.get("availability"))),
                )
                break

    if meta.get("og:title"):
        candidate.set(
            "name",
            strip_site_suffix(clean_title(meta["og:title"]), brand_name),
            Provenance("microdata", url, "og:title"),
        )
    if title_match:
        candidate.set(
            "name",
            strip_site_suffix(clean_title(_unescape(title_match.group(1))), brand_name),
            Provenance("heuristic", url, "<title>"),
        )
    return product is not None


# Availability answers one of the two directions and not the other.
#
#   A product the brand's own shop sells today is NOT discontinued. That is a
#   fact about the product, and the shop software states it plainly.
#
#   A product that is out of stock may be anything: sold out until Thursday,
#   waiting for a part, or gone for ever. Nothing in the data separates those,
#   so nothing is written -- the field stays empty and the review decides.
#
# Only an explicit statement, schema.org's `Discontinued`, sets it to true.
STILL_SOLD = (
    "instock", "onlineonly", "instoreonly", "limitedavailability",
    "presale", "preorder", "backorder",
)


def availability_says_current(availability: Optional[str]) -> Optional[bool]:
    """False (not discontinued) when a shop states the product is on sale."""
    if not availability:
        return None
    word = str(availability).rsplit("/", 1)[-1].strip().lower().replace(" ", "")
    if word == "discontinued":
        return True
    return False if word in STILL_SOLD else None


def apply_shopify_product(
    candidate: Candidate, product: dict, url: str, currency: Optional[str] = None
) -> None:
    """Fill the candidate from one entry of a Shopify /products.json answer.

    This is the shop's own catalogue, not a reading of a page, so it is the best
    source there is: the name, the text, every version with its article number
    and price, and the images, for one request per two hundred and fifty
    products.

    Two things it does not carry. There is no currency -- the shop writes that
    into its pages, and `platform.shopify_currency` reads it from the home page
    that is already stored. And `product_type` is the shop's own word for a
    category ("Amplifiers", "New in"), which is a hint for the review and never
    a hifilog sub category.
    """
    source = Provenance("products_json", url, "shopify products.json")
    name, variant = split_variant(_text(product.get("title")))
    candidate.set("name", name, source)
    candidate.set("variant_name", variant, source)
    candidate.source_category = _text(product.get("product_type")) or None

    variants = [item for item in (product.get("variants") or []) if isinstance(item, dict)]
    candidate.variants = [
        {
            "name": _text(item.get("title")),
            "sku": item.get("sku") or None,
            "price": parse_price(item.get("price")),
        }
        for item in variants
    ]
    # The same rule as everywhere: one version means the article number belongs
    # to the product; several mean each number belongs to one version.
    only_sku = variants[0].get("sku") if len(variants) == 1 else None
    if looks_like_model(only_sku) and sku_is_the_model(only_sku, name):
        candidate.set("model_no", str(only_sku), source)

    prices = [parse_price(item.get("price")) for item in variants]
    prices = [price for price in prices if price and price > 0]
    if prices:
        # The lowest, because that is the price of the product as sold, before
        # a more expensive finish or a longer cable is chosen.
        candidate.set("price", min(prices), source)
        if currency:
            candidate.set("price_currency", currency.upper()[:3], source)

    images = [image.get("src") for image in (product.get("images") or []) if image.get("src")]
    candidate.set("image_urls", images, source)

    # `available` is the shop's own word for "this can be put in a basket".
    if any(item.get("available") is True for item in variants):
        candidate.set("discontinued", False, source)


def _offers(product: dict) -> List[dict]:
    offers = product.get("offers")
    if isinstance(offers, dict):
        if "offers" in offers:
            return [offer for offer in offers["offers"] if isinstance(offer, dict)] + [offers]
        return [offers]
    if isinstance(offers, list):
        return [offer for offer in offers if isinstance(offer, dict)]
    return []


def _images(product: dict) -> List[str]:
    image = product.get("image")
    if isinstance(image, str):
        return [image]
    if isinstance(image, dict):
        # `url` is a list on more sites than the schema suggests.
        url = image.get("url")
        if isinstance(url, list):
            return [item for item in url if isinstance(item, str)]
        return [url] if isinstance(url, str) else []
    if isinstance(image, list):
        out = []
        for item in image:
            if isinstance(item, str):
                out.append(item)
            elif isinstance(item, dict) and item.get("url"):
                out.append(item["url"])
        return out
    return []


def _text(value: Any) -> Optional[str]:
    if isinstance(value, str):
        return _unescape(value).strip() or None
    if isinstance(value, dict):
        return _text(value.get("name") or value.get("@value"))
    if isinstance(value, list) and value:
        return _text(value[0])
    return None


def _unescape(value: str) -> str:
    import html as html_module

    return html_module.unescape(re.sub(r"\s+", " ", value))


class _Stripper(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.parts: List[str] = []
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "noscript", "svg"):
            self.skip += 1
        elif tag in ("p", "br", "li", "tr", "div", "h1", "h2", "h3", "h4", "table"):
            self.parts.append("\n")

    def handle_endtag(self, tag):
        if tag in ("script", "style", "noscript", "svg") and self.skip:
            self.skip -= 1
        elif tag in ("td", "th"):
            self.parts.append("\t")

    def handle_data(self, data):
        if not self.skip:
            self.parts.append(data)


def _strip_tags(html: str) -> str:
    parser = _Stripper()
    try:
        parser.feed(html)
    except Exception:
        return re.sub(r"<[^>]+>", " ", html)
    text = "".join(parser.parts)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n\s*\n+", "\n", text)
    return text.strip()


def page_text(html: str, limit: int = 12000) -> str:
    """The page as text, for the extractor that reads it.

    The limit is not only a cost control. A product page carries a footer, a
    cookie banner and a list of other products, and all of it is text that the
    extractor can mistake for the product in front of it. The first part of the
    document is where the product is described, so a cut at the start is safer
    than a cut at the end.
    """
    import html as html_module

    text = _strip_tags(html)
    text = html_module.unescape(text)
    return text[:limit]


def apply_squarespace_item(
    candidate: Candidate, item: dict, url: str, brand_name: Optional[str] = None
) -> None:
    """Fill the candidate from one item of a Squarespace JSON answer.

    This is the data behind the page rather than a reading of the page, so it
    is trusted like the markup. It gives what the markup on these sites usually
    leaves out: the article number and the price of each variant, and the
    variant names themselves.

    The price is in the smallest unit of the currency on some sites and in the
    major unit on others, so only `value`, which Squarespace documents as a
    decimal string, is read. A price that cannot be read is left empty rather
    than guessed at, which is the rule everywhere in this pipeline.
    """
    source = Provenance("products_json", url, "squarespace ?format=json")
    name, variant = split_variant(strip_site_suffix(_text(item.get("title")), brand_name))
    candidate.set("name", name, source)
    candidate.set("variant_name", variant, source)

    content = item.get("structuredContent") or {}
    variants = [entry for entry in (content.get("variants") or []) if isinstance(entry, dict)]
    if len(variants) == 1:
        # One variant means the article number belongs to the product. With
        # several, each number belongs to one version -- the same rule as for a
        # schema.org offer.
        sku = variants[0].get("sku")
        if looks_like_model(sku) and sku_is_the_model(sku, name):
            candidate.set("model_no", str(sku), source)
    for entry in variants:
        money = entry.get("priceMoney") or {}
        price = parse_price(money.get("value"))
        if price and price > 0:
            candidate.set("price", price, source)
            currency = money.get("currency")
            if isinstance(currency, str) and currency.strip():
                candidate.set("price_currency", currency.upper()[:3], source)
            break

    # A variant with stock, or with no stock limit, is a product on sale.
    if any(
        entry.get("unlimited") is True or (entry.get("qtyInStock") or 0) > 0
        for entry in variants
    ):
        candidate.set("discontinued", False, source)

    images = [entry.get("assetUrl") for entry in (item.get("items") or [])
              if isinstance(entry, dict) and entry.get("assetUrl")]
    if item.get("assetUrl"):
        images.insert(0, item["assetUrl"])
    candidate.set("image_urls", list(dict.fromkeys(images)), source)


def apply_woocommerce_product(candidate: Candidate, product: dict, url: str,
                              brand_name: Optional[str] = None) -> None:
    """Fill the candidate from one entry of a WooCommerce Store API answer.

    The shop's own record of the product, so it is trusted like the markup. The
    shop's category list is carried as the shop's word, never as a sub category
    of this catalogue.
    """
    from .platform import woocommerce_price

    source = Provenance("products_json", url, "woocommerce store api")
    name, variant = split_variant(strip_site_suffix(_text(product.get("name")), brand_name))
    candidate.set("name", name, source)
    candidate.set("variant_name", variant, source)

    sku = product.get("sku")
    variations = product.get("variations") or []
    if looks_like_model(sku) and not variations and sku_is_the_model(sku, name):
        candidate.set("model_no", str(sku), source)

    amount, currency = woocommerce_price(product.get("prices"))
    if amount:
        candidate.set("price", amount, source)
        if currency:
            candidate.set("price_currency", currency.upper()[:3], source)

    images = [image.get("src") for image in (product.get("images") or [])
              if isinstance(image, dict) and image.get("src")]
    candidate.set("image_urls", images, source)

    # `is_purchasable` is the shop's own answer to "can this be bought". Being
    # out of stock is not read as discontinued: a backorder is still a sale.
    if product.get("is_purchasable") is True and (
        product.get("is_in_stock") is True or product.get("is_on_backorder") is True
    ):
        candidate.set("discontinued", False, source)

    categories = [category.get("name") for category in (product.get("categories") or [])
                  if isinstance(category, dict) and category.get("name")]
    if categories:
        candidate.source_category = categories[0]
    candidate.variants = [{"name": None, "sku": sku, "price": amount}] if sku else []
