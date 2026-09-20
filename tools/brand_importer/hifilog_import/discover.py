"""Find the product pages of a brand site.

The sequence is always the same, and each step is cheaper than the step below
it. The crawler stops at the first step that gives a usable number of URLs.

  1. Sitemap. robots.txt often names it. If it does not, the usual paths are
     tried: /sitemap.xml, /sitemap_index.xml, /wp-sitemap.xml, /sitemap.xml.gz.
     A sitemap index is followed, to a maximum depth.
  2. Shopify. Shopify shops answer /products.json with the full product list as
     JSON. This is a public part of the shop software, not a private API, and
     it gives cleaner data than the HTML.
  3. Link walk. Start at the home page, follow links on the same host, and stop
     at a page limit. This is the last choice, because it is slow and it finds
     much that is not a product.

Which URL is a product page is decided by score, not by one rule. The path
segments that a shop system uses (/products/, /produkte/, /shop/) raise the
score. Segments that are never a product (/blog/, /news/, /support/, /cart/)
make the URL fail immediately. A URL with a middle score is kept and is marked,
so that the extraction step can decide.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Iterable, List, Optional, Set
from urllib.parse import urljoin, urlparse, urlunparse
from xml.etree import ElementTree

from . import log
from .fetch import Fetcher

SITEMAP_GUESSES = (
    "/sitemap.xml",
    "/sitemap_index.xml",
    "/sitemap-index.xml",
    "/wp-sitemap.xml",
    "/sitemap.xml.gz",
)

# Path segments that a shop or a catalogue uses for a single product.
PRODUCT_SEGMENTS = (
    "product", "products", "produkt", "produkte", "produit", "produits",
    "prodotti", "producto", "productos", "shop", "store", "catalogue",
    "catalog", "range", "models", "model",
    # Wix Stores writes every product under this one path.
    "product-page",
)

# Segments that name a list of products rather than one product. On Shopify
# /collections/<name> is a list and /collections/<name>/products/<name> is a
# product, so the segment alone must not raise the score. This was learnt from a
# real crawl: a collection page carries a Product object for the first product
# on it, so it passes every later check and enters the catalogue under the name
# of a product that is not the subject of the page.
LIST_SEGMENTS = ("collections", "collection", "kategorie", "category", "series")

# Path segments that are never a single product.
REJECT_SEGMENTS = (
    "pages", "page",
    # Squarespace writes its own assets and blocks under /content/. One sample
    # site had 434 of them in a sitemap of 461.
    "content",
    "blog",
    # A forum or a news archive on the brand's own site. One Wix site had 1298
    # pages of forum archive in its sitemap, all of them crawled.
    "forum", "forums", "discussion", "discussions", "thread", "threads",
    "post", "posts", "topic", "topics", "archive", "community", "news", "press", "support", "service", "download", "downloads",
    "manual", "manuals", "faq", "contact", "about", "career", "careers",
    "dealer", "dealers", "where-to-buy", "cart", "checkout", "account",
    "login", "search", "policies", "legal", "privacy", "terms", "imprint",
    "impressum", "datenschutz", "agb", "basket", "wishlist", "review",
    "reviews", "awards", "events", "gallery", "tag", "tags", "category",
    "categories", "author", "feed", "rss", "sitemap", "cdn-cgi", "wp-json",
    "wp-content", "wp-admin", "jobs", "story", "stories", "history",
    "technology", "sustainability", "warranty", "spare", "spares",
)

REJECT_EXTENSIONS = (
    ".pdf", ".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".zip",
    ".mp4", ".mp3", ".doc", ".docx", ".xls", ".xlsx", ".css", ".js",
)


# The language codes that a shop puts in front of its paths. Only the first
# segment is tested against this, so a product whose name happens to be two
# letters is not affected.
LANGUAGES = frozenset(
    "aa ab af ak am ar as az be bg bm bn bo br bs ca cs cy da de dz ee el en eo "
    "es et eu fa ff fi fo fr fy ga gd gl gu gv ha he hi hr hu hy id ig is it ja "
    "ka kk kl km kn ko ks ku kw ky lb lg ln lo lt lu lv mg mk ml mn mr ms mt my "
    "nb nd ne nl nn no om or pa pl ps pt qu rm rn ro ru rw se sg si sk sl sn so "
    "sq sr sv sw ta te tg th ti tr uk ur uz vi yo zh zu".split()
)


def locale_prefix(path: str) -> Optional[str]:
    """The language segment at the start of a path, if there is one.

    A shop offers the same product under /products/x, /en-mx/products/x and
    /fr/products/x. These are one product. Crawling all of them costs three
    times the requests and three times the extraction, and the copy that is kept
    is then decided by the alphabet: in the first real crawl fourteen of fifteen
    products were taken from the Mexican storefront, with its prices in dollars,
    while the site's own pages were never read.
    """
    first = path.strip("/").split("/")[0].lower()
    root = re.split(r"[-_]", first)[0]
    if root in LANGUAGES and len(first) <= 5:
        return first
    return None


def prefer_canonical(urls: Iterable[str]) -> List[str]:
    """One URL for each product: the one without a language prefix.

    A translated URL is kept only when the untranslated one is not in the set,
    and then only one language, so that a shop that has no default storefront is
    still read one time rather than six.
    """
    plain = set()
    translated: dict = {}
    for url in urls:
        parts = urlparse(url)
        prefix = locale_prefix(parts.path)
        if not prefix:
            plain.add(url)
            continue
        rest = "/" + parts.path.strip("/")[len(prefix) :].lstrip("/")
        key = urlunparse((parts.scheme, parts.netloc, rest, "", "", ""))
        # English first, then the shortest prefix, so the choice does not depend
        # on the order of the sitemap.
        translated.setdefault(key, []).append((prefix != "en", len(prefix), url))

    kept = list(plain)
    for key, options in translated.items():
        if key in plain:
            continue
        kept.append(sorted(options)[0][2])
    return kept


@dataclass
class Candidate:
    url: str
    score: int
    source: str  # sitemap | products_json | link_walk

    @property
    def likely(self) -> bool:
        return self.score >= 2


def _bare_host(netloc: str) -> str:
    """Host name without the www prefix and without a port."""
    host = netloc.lower().split(":")[0]
    return host[4:] if host.startswith("www.") else host


def normalise_url(url: str) -> str:
    """Remove the parts of a URL that do not change the page.

    Query strings on brand sites are nearly always a tracking parameter or a
    colour selection, and a fragment never changes the document. Two URLs that
    differ only there are one page, and must be crawled one time.
    """
    parts = urlparse(url)
    path = re.sub(r"/{2,}", "/", parts.path)
    if len(path) > 1 and path.endswith("/"):
        path = path[:-1]
    return urlunparse((parts.scheme.lower(), parts.netloc.lower(), path, "", "", ""))


def _plain(segment: str) -> str:
    """A path segment without its file extension.

    An older site has no directories: it writes support.html, history.html and
    power_amp.html beside its product pages. Comparing the raw segment lets
    every one of those through, because "support.html" is not "support".
    """
    return re.sub(r"\.(html?|php|aspx?|jsp)$", "", segment)


def score_url(url: str, home: str) -> int:
    """Give a URL a score. Below 2 means: probably not one product page."""
    parts = urlparse(url)
    if _bare_host(parts.netloc) != _bare_host(urlparse(home).netloc):
        return -1
    path = parts.path.lower()
    if any(path.endswith(extension) for extension in REJECT_EXTENSIONS):
        return -1
    segments = [_plain(segment) for segment in path.split("/") if segment]
    if not segments:
        return -1
    if any(segment in REJECT_SEGMENTS for segment in segments):
        return -1
    # A list segment is allowed only when a product segment follows it:
    # /collections/floorstanders is a list, /collections/floorstanders/products/
    # aria-5 is a product.
    for index, segment in enumerate(segments):
        if segment in LIST_SEGMENTS and not any(
            later in PRODUCT_SEGMENTS for later in segments[index + 1 :]
        ):
            return -1

    score = 0
    if any(segment in PRODUCT_SEGMENTS for segment in segments):
        score += 2
    # A leaf below a product segment is more probably one product than the
    # segment itself: /products/ is a list, /products/cxa81 is a product.
    for index, segment in enumerate(segments[:-1]):
        if segment in PRODUCT_SEGMENTS and index == len(segments) - 2:
            score += 1
    if len(segments) >= 2:
        score += 1
    last = segments[-1]
    # A model name nearly always has a digit or a hyphen in it.
    if re.search(r"\d", last) or "-" in last:
        score += 1
    if len(segments) > 4:
        score -= 1
    return score


def urls_from_sitemap(text: str) -> tuple:
    """Return (page urls, sitemap urls) from one sitemap document.

    The document type decides which list a <loc> belongs to: a <sitemapindex>
    names other sitemaps, a <urlset> names pages. This is one pass over the
    tree. Do not look for the parent of each element: that is one more pass for
    each <loc>, and a large sitemap has 50000 of them.
    """
    pages: List[str] = []
    sitemaps: List[str] = []
    try:
        root = ElementTree.fromstring(text.strip())
    except ElementTree.ParseError:
        return pages, sitemaps
    is_index = root.tag.rsplit("}", 1)[-1] == "sitemapindex"
    target = sitemaps if is_index else pages
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1] == "loc" and element.text:
            target.append(element.text.strip())
    return pages, sitemaps


def discover(
    home: str,
    fetcher: Fetcher,
    store,
    brand_slug: str,
    max_sitemaps: int = 40,
    max_pages: int = 3000,
) -> List[Candidate]:
    home = home.rstrip("/")
    found: dict = {}

    def add(url: str, source: str) -> None:
        url = normalise_url(url)
        if url in found:
            return
        score = score_url(url, home)
        if score < 0:
            return
        found[url] = Candidate(url, score, source)

    # 1. Sitemaps
    from_robots = list(fetcher.sitemaps_from_robots(home))
    if from_robots:
        log.info(f"  robots.txt names {len(from_robots)} sitemap(s)")
    queue: List[str] = list(from_robots)
    queue += [home + guess for guess in SITEMAP_GUESSES]
    seen_sitemaps: Set[str] = set()
    while queue and len(seen_sitemaps) < max_sitemaps:
        sitemap_url = queue.pop(0)
        if sitemap_url in seen_sitemaps:
            continue
        seen_sitemaps.add(sitemap_url)
        response = fetcher.get(sitemap_url)
        store.put(
            sitemap_url, brand_slug, "sitemap", response.status,
            response.content_type, response.text, response.error,
        )
        if not response.text or response.status != 200:
            continue
        pages, sitemaps = urls_from_sitemap(response.text)
        before = len(found)
        for page in pages:
            add(page, "sitemap")
        log.detail(
            f"{sitemap_url}: {len(pages)} url(s), {len(sitemaps)} sitemap(s), "
            f"{len(found) - before} kept"
        )
        # Prefer a sitemap that names products over one that names articles.
        queue += sorted(
            sitemaps,
            key=lambda url: 0 if any(word in url.lower() for word in ("product", "shop")) else 1,
        )

    if found:
        log.info(f"  sitemaps gave {len(found)} candidate URL(s)")
    else:
        log.info("  no sitemap, trying the shop software")

    # 2. Shopify product list
    if not any(candidate.likely for candidate in found.values()):
        for page_number in range(1, 6):
            url = f"{home}/products.json?limit=250&page={page_number}"
            response = fetcher.get(url)
            if not response.text or response.status != 200:
                break
            try:
                products = json.loads(response.text).get("products", [])
            except json.JSONDecodeError:
                break
            if not products:
                break
            store.put(
                url, brand_slug, "sitemap", response.status,
                response.content_type, response.text, response.error,
            )
            log.info(f"  products.json page {page_number}: {len(products)} product(s)")
            for product in products:
                add(f"{home}/products/{product.get('handle')}", "products_json")

    # 3. Link walk, only when the steps above gave nothing
    if not any(candidate.likely for candidate in found.values()):
        log.warn(f"{brand_slug}: no sitemap and no shop list, walking the links")
        for url in _link_walk(home, fetcher, store, brand_slug, limit=200):
            add(url, "link_walk")

    # A site with flat URLs. Squarespace and other page builders often put a
    # product at the top level -- /emotion-alnico-8, /zmfcables-2 -- with no
    # segment that says "product" anywhere in the path. The strict rule scores
    # those below the bar and three of the five sites in the first sample gave
    # nothing at all. So when the strict rule finds nothing, the bar is lowered
    # for that brand rather than the brand being lost. The pages that this lets
    # through are refused later, by the extractor, which can see that they carry
    # no product.
    if found and not any(candidate.likely for candidate in found.values()):
        widened = 0
        for candidate in found.values():
            if candidate.score >= 1:
                candidate.score = 2
                widened += 1
        if widened:
            log.warn(
                f"{brand_slug}: no obvious product path, taking {widened} "
                "top level page(s) instead"
            )

    # Take the translations out before anything is fetched, not afterwards: the
    # saving is in the requests that are never made.
    before = len(found)
    canonical = set(prefer_canonical(found.keys()))
    found = {url: item for url, item in found.items() if url in canonical}
    if len(found) < before:
        log.info(f"  {before - len(found)} translated URL(s) dropped")

    candidates = sorted(found.values(), key=lambda item: (-item.score, item.url))
    return candidates[:max_pages]


def discover_shopify_catalog(
    home: str, fetcher: Fetcher, store, brand_slug: str, max_products: int = 5000
) -> int:
    """Read a Shopify shop's whole catalogue instead of crawling its pages.

    Every Shopify shop answers /products.json with its products, 250 at a time,
    in the shop software's own structure. One request therefore replaces 250
    page fetches and 250 extractions, and what comes back is better than what
    the pages carry: every version with its article number and its price.

    This is a part of the shop software that Shopify serves publicly, not a
    private interface, and reading it is far lighter on the site than crawling
    it.

    Returns the number of products found. Zero means the shop did not answer,
    and the caller falls back to the ordinary discovery.
    """
    home = home.rstrip("/")
    total = 0
    for page_number in range(1, (max_products // 250) + 2):
        url = f"{home}/products.json?limit=250&page={page_number}"
        response = fetcher.get(url)
        if not response.text or response.status != 200:
            break
        products = _catalog_products(response.text)
        if not products:
            break
        store.put(
            url, brand_slug, "catalog", response.status,
            response.content_type, response.text, response.error,
        )
        total += len(products)
        log.detail(f"{url}: {len(products)} product(s)")
        if len(products) < 250 or total >= max_products:
            break
    return total


def discover_woocommerce_catalog(
    home: str, fetcher: Fetcher, store, brand_slug: str, max_products: int = 5000
) -> int:
    """Read a WooCommerce shop through its own Store API.

    The same idea as the Shopify catalogue, and for a stronger reason: these
    shops write no product markup at all, so without this they give nothing.
    """
    from .platform import parse_woocommerce_catalog, woocommerce_catalog_url

    total = 0
    for page_number in range(1, (max_products // 100) + 2):
        url = woocommerce_catalog_url(home, page_number)
        response = fetcher.get(url)
        if not response.text or response.status != 200:
            break
        products = parse_woocommerce_catalog(response.text)
        if not products:
            break
        store.put(
            url, brand_slug, "catalog_woo", response.status,
            response.content_type, response.text, response.error,
        )
        total += len(products)
        log.detail(f"{url}: {len(products)} product(s)")
        if len(products) < 100 or total >= max_products:
            break
    return total


def _catalog_products(text: str) -> List[dict]:
    from .platform import parse_shopify_catalog

    return parse_shopify_catalog(text)


def _link_walk(home: str, fetcher: Fetcher, store, brand_slug: str, limit: int) -> Iterable[str]:
    seen: Set[str] = set()
    queue = [home]
    visited = 0
    while queue and visited < limit:
        url = queue.pop(0)
        if url in seen:
            continue
        seen.add(url)
        response = fetcher.get(url)
        visited += 1
        store.put(
            url, brand_slug, "page", response.status,
            response.content_type, response.text, response.error,
        )
        if not response.text:
            continue
        for match in re.finditer(r'href=["\']([^"\'#]+)["\']', response.text, re.I):
            link = normalise_url(urljoin(url, match.group(1)))
            if score_url(link, home) >= 0 and link not in seen:
                queue.append(link)
                yield link
