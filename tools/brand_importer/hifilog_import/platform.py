"""Which system a brand site is built with, and what that system offers.

This decides how much of a site can be read without a language model. The
answer is not the same for every builder:

  * Shopify writes a schema.org Product object into every product page, and it
    answers /products.json with the whole catalogue. Best case.
  * Squarespace Commerce writes a Product object into a product page, and every
    page also answers `?format=json`, which gives the same product as the data
    behind the page: title, variants, article numbers and price per variant.
    This is a documented feature of the platform, not a private interface.
    Squarespace itself says it is not a replacement for its API and can change,
    so it is used as an addition to the markup, never as the only source.
  * Wix writes a Product object into the pages of a Wix Stores shop. Wix says
    it does this for store product pages, booking pages, blog posts and events.
    A Wix site without a shop is only a brochure, and holds no product data at
    all.
  * WooCommerce and other WordPress shops write a Product object. A WordPress
    site without a shop does not.

The important consequence is the one that is easy to miss: on every one of these
builders the markup exists **only where the brand runs a shop**. A brand that
shows its products but sells through dealers -- which is most of hi-fi -- has a
page for each product and no product markup anywhere on the site. Knowing the
builder therefore does not predict the data; knowing builder plus shop does.
That is why detection reports both.
"""

from __future__ import annotations

import json
import re
from typing import Dict, List, Optional, Tuple

# Each entry: platform, then the strings that only that platform writes into a
# page. Ordered, because a Shopify shop on a WordPress site must read as
# Shopify: the more specific fingerprint is tested first.
FINGERPRINTS: Tuple[Tuple[str, Tuple[str, ...]], ...] = (
    ("shopify", ("cdn.shopify.com", "Shopify.theme", "shopify-features", "myshopify.com")),
    ("squarespace", ("static1.squarespace.com", "squarespace-cdn.com",
                     "Squarespace.afterBodyLoad", "squarespace.com/universal")),
    ("wix", ("static.parastorage.com", "wixstatic.com", "wix-code",
             "X-Wix-Published-Version", "_partials/wix-thunderbolt")),
    ("bigcartel", ("bigcartel.com",)),
    ("webflow", ("assets.website-files.com", "webflow.js", "cdn.prod.website-files.com")),
    ("jimdo", ("jimdo.com", "jimstatic.com")),
    ("weebly", ("weebly.com", "editmysite.com")),
    ("woocommerce", ("wp-content/plugins/woocommerce", "woocommerce-page", "wc-add-to-cart")),
    ("wordpress", ("wp-content/", "wp-includes/", "wp-json")),
    ("typo3", ("typo3temp", "typo3conf")),
    ("drupal", ("/sites/default/files", "Drupal.settings", "drupal.js")),
    ("joomla", ("/media/jui/", "joomla")),
)

# Where each builder puts one product. These are added to the URL score, so a
# Wix shop is found even though "product-page" is a word no other system uses.
PRODUCT_PATHS: Dict[str, Tuple[str, ...]] = {
    "shopify": ("products",),
    "squarespace": ("shop", "store", "products", "product"),
    "wix": ("product-page", "product"),
    "woocommerce": ("product", "produkt", "shop"),
    "bigcartel": ("product",),
}

# What a shop writes into a page, whatever the builder. A site with none of
# these sells nothing on the site itself.
SHOP_MARKS = (
    "add to cart", "add to basket", "in den warenkorb", "addtocart",
    '"@type":"offer"', '"@type": "offer"', "schema.org/offer",
    "shopify-features", "woocommerce-page", "sqs-add-to-cart-button",
    "wix-ecommerce", "data-item-price",
)


def detect(html: Optional[str], headers: Optional[Dict[str, str]] = None) -> str:
    """The builder of a page, or "unknown"."""
    if not html:
        return "unknown"
    lowered = html.lower()
    for platform, marks in FINGERPRINTS:
        if any(mark.lower() in lowered for mark in marks):
            return platform
    if headers:
        server = " ".join(f"{key} {value}" for key, value in headers.items()).lower()
        for platform, marks in FINGERPRINTS:
            if any(mark.lower() in server for mark in marks):
                return platform
    return "unknown"


def has_shop(html: Optional[str]) -> bool:
    """True when the page shows that the brand sells on its own site."""
    if not html:
        return False
    lowered = html.lower()
    return any(mark in lowered for mark in SHOP_MARKS)


def has_product_markup(html: Optional[str]) -> bool:
    """True when a schema.org Product object is in the page."""
    if not html:
        return False
    return bool(
        re.search(
            r'application/ld\+json[^>]*>(?:(?!</script>).)*"@type"\s*:\s*"?\[?\s*"?Product',
            html,
            re.I | re.S,
        )
    )


def product_segments(platform: str) -> Tuple[str, ...]:
    return PRODUCT_PATHS.get(platform, ())


def squarespace_json_url(url: str) -> str:
    """The same page as data.

    Documented by Squarespace as `?format=json-pretty` for reading. The compact
    form is used here because nothing reads it with human eyes.
    """
    joiner = "&" if "?" in url else "?"
    return f"{url}{joiner}format=json"


def parse_squarespace(text: str) -> List[dict]:
    """The product items of a Squarespace JSON answer.

    One page answers with `item`, a collection page with `items`. Anything that
    is not a product -- a blog entry, a gallery image -- has no
    `structuredContent.productType` and is left out.
    """
    try:
        data = json.loads(text)
    except (json.JSONDecodeError, TypeError):
        return []
    if not isinstance(data, dict):
        return []
    candidates = []
    if isinstance(data.get("item"), dict):
        candidates.append(data["item"])
    if isinstance(data.get("items"), list):
        candidates += [item for item in data["items"] if isinstance(item, dict)]
    return [
        item for item in candidates
        if isinstance(item.get("structuredContent"), dict)
        and item["structuredContent"].get("productType") is not None
    ]


def shopify_currency(html: Optional[str]) -> Optional[str]:
    """The currency of a Shopify shop, read from any of its pages.

    `/products.json` gives a price and no currency, which would make every
    Shopify price a number without a meaning. The shop writes its currency into
    its own pages, and the home page is already stored by `platforms`, so this
    costs no request at all.
    """
    if not html:
        return None
    for pattern in (
        r'Shopify\.currency\s*=\s*\{[^}]*"active"\s*:\s*"([A-Z]{3})"',
        r'"currency"\s*:\s*"([A-Z]{3})"',
        r'itemprop=["\']priceCurrency["\'][^>]*content=["\']([A-Z]{3})["\']',
        r'"priceCurrency"\s*:\s*"([A-Z]{3})"',
    ):
        match = re.search(pattern, html)
        if match:
            return match.group(1)
    return None


def parse_shopify_catalog(text: Optional[str]) -> List[dict]:
    """The products of one /products.json answer."""
    try:
        data = json.loads(text or "")
    except (json.JSONDecodeError, TypeError):
        return []
    products = data.get("products") if isinstance(data, dict) else None
    return [item for item in (products or []) if isinstance(item, dict)]


def woocommerce_catalog_url(home: str, page: int = 1, per_page: int = 100) -> str:
    """The WooCommerce Store API, which a shop serves to its own shop pages.

    WooCommerce shops in the first sample wrote no schema.org Product object at
    all: the SEO plugin had replaced the markup with BreadcrumbList, ItemPage,
    Organization and WebSite, and nothing else. 382 product pages of one shop
    therefore gave nothing.

    The Store API is the answer. It is the read side of the shop's own software,
    public and without a key, and it gives the catalogue in the shape the shop
    keeps it in: name, text, article number, price, currency, images and the
    shop's own categories.
    """
    return f"{home.rstrip('/')}/wp-json/wc/store/v1/products?per_page={per_page}&page={page}"


def parse_woocommerce_catalog(text: Optional[str]) -> List[dict]:
    """The products of one Store API answer, which is a plain JSON array."""
    try:
        data = json.loads(text or "")
    except (json.JSONDecodeError, TypeError):
        return []
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    # Some installations wrap the array, and an error is an object with a code.
    if isinstance(data, dict) and isinstance(data.get("products"), list):
        return [item for item in data["products"] if isinstance(item, dict)]
    return []


def woocommerce_price(prices: Optional[dict]) -> tuple:
    """(amount, currency) from a Store API price object.

    The Store API states a price in the smallest unit of the currency as a
    string, with the number of decimals beside it: 345000 with
    currency_minor_unit 2 is 3450.00. Reading the number without the exponent
    would put a three thousand euro amplifier in the catalogue at 345000.
    """
    if not isinstance(prices, dict):
        return None, None
    raw = prices.get("price")
    currency = prices.get("currency_code")
    if raw in (None, ""):
        return None, currency if isinstance(currency, str) else None
    try:
        minor = int(prices.get("currency_minor_unit", 2))
        amount = int(str(raw)) / (10 ** minor)
    except (TypeError, ValueError):
        return None, currency if isinstance(currency, str) else None
    return (amount if amount > 0 else None), (currency if isinstance(currency, str) else None)
