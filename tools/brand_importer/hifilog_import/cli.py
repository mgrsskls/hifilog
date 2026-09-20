"""Command line for the importer.

Four commands, which are the four stages of the pipeline. Each writes its
result to disk and reads the result of the stage before it, so any stage can be
run again on its own. This matters most for `extract`: the extraction rules will
change many times, and each change must not cost another crawl.

  discover  find the product URLs of each brand      -> urls.jsonl
  crawl     fetch those pages into the document store -> documents.sqlite3
  extract   turn the documents into candidates        -> candidates.jsonl
  report    write a CSV of the candidates for review  -> candidates.csv

Input is a CSV of brands with the columns slug, name, website. Write it with:

  bin/rails import:brands > tools/brand_importer/var/brands.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional

from . import log
from . import classify as classifier
from .cache import DocumentStore, FileCache
from . import validations as validations_module
from .candidates import Candidate, Provenance
from .discover import (
    discover,
    discover_shopify_catalog,
    discover_woocommerce_catalog,
    normalise_url,
    prefer_canonical,
    score_url,
)
from .extract_markup import (
    apply_markup,
    apply_shopify_product,
    apply_woocommerce_product,
    apply_squarespace_item,
    page_text,
)
from .extract_text import Schema, apply_text_extraction, build_prompt, call_model
from . import platform as platforms_module
from .fetch import Fetcher
from .normalize import shop_state
from .scope import OtherBrands, condition, out_of_scope

# Raise this whenever a change to the extraction would give a different answer
# for the same page. Every cached extraction is then ignored, and the next run
# reads the stored pages again with the new rules. It costs one run; forgetting
# to raise it costs a wrong answer that nothing will correct.
EXTRACTOR_VERSION = "2026-09-19.1"

HERE = Path(__file__).resolve().parent.parent
# Where the crawl keeps its work. It is a lot of data and it is written
# constantly, so it can be moved: set HIFILOG_IMPORT_VAR to put it on a local
# disk. A network or a container mount is a bad place for a SQLite file, and
# some of them refuse the file locks that SQLite needs.
VAR = Path(os.environ.get("HIFILOG_IMPORT_VAR") or (HERE / "var"))


def read_brands(path: Path, only: List[str], platforms: Optional[List[str]] = None) -> List[dict]:
    """The brands to work on: all of them, or those named, or those on a builder."""
    with open(path, newline="", encoding="utf-8") as handle:
        rows = [row for row in csv.DictReader(handle) if row.get("website")]
    if only:
        wanted = {value.lower() for value in only}
        rows = [row for row in rows if row["slug"].lower() in wanted]
    if platforms:
        found = read_platforms()
        if not found:
            log.warn("--platform needs platforms.csv. Run the platforms stage first.")
            return []
        wanted_platforms = {value.lower() for value in platforms}
        rows = [row for row in rows if found.get(row["slug"], "").lower() in wanted_platforms]
    return rows


def command_discover(args) -> None:
    brands = read_brands(Path(args.brands), args.brand, args.platform)
    store = DocumentStore(VAR / "documents.sqlite3")
    fetcher = Fetcher(delay=args.delay, obey_robots=not args.ignore_robots)
    output = VAR / "urls.jsonl"

    # A run for one brand must not delete the URLs of the others. The file is
    # read first and the rows of the brands in this run are replaced; everything
    # else is written back unchanged.
    kept: List[str] = []
    if output.exists():
        wanted = {brand["slug"] for brand in brands}
        for line in open(output, encoding="utf-8"):
            try:
                if json.loads(line).get("brand_slug") not in wanted:
                    kept.append(line.rstrip("\n"))
            except json.JSONDecodeError:
                continue

    log.step(f"discover: {len(brands)} brand(s), {args.delay}s between requests")
    if kept:
        log.info(f"  keeping {len(kept)} URL(s) of brands that are not in this run")
    if args.ignore_robots:
        log.warn("robots.txt is ignored. Do not do this on a site you do not own.")

    platform_by_brand = read_platforms()
    totals = {
        "brands": 0, "with URLs": 0, "without URLs": 0, "product URLs": 0,
        "products from a shop catalogue": 0, "brands read as a catalogue": 0,
    }
    by_source: Dict[str, int] = {}
    empty: List[str] = []

    with open(output, "w", encoding="utf-8") as handle:
        for line in kept:
            handle.write(line + "\n")
        for number, brand in enumerate(brands, start=1):
            platform = platform_by_brand.get(brand["slug"], "")
            log.step(
                f"[{number}/{len(brands)}] {brand['slug']} {brand['website']}"
                + (f" ({platform})" if platform else "")
            )
            totals["brands"] += 1

            # A Shopify shop is read as a catalogue, not crawled. One request
            # replaces 250 pages, so nothing is written to urls.jsonl for it and
            # `crawl` has nothing to do.
            if platform == "shopify":
                found = discover_shopify_catalog(
                    brand["website"], fetcher, store, brand["slug"]
                )
                if found:
                    totals["products from a shop catalogue"] += found
                    totals["brands read as a catalogue"] += 1
                    totals["with URLs"] += 1
                    log.ok(f"{brand['slug']}: {found} product(s) from products.json")
                    continue
                log.warn(f"{brand['slug']}: products.json gave nothing, crawling instead")

            # WooCommerce shops in the sample wrote no product markup at all, so
            # the Store API is not an improvement here but the only source.
            if platform == "woocommerce":
                found = discover_woocommerce_catalog(
                    brand["website"], fetcher, store, brand["slug"]
                )
                if found:
                    totals["products from a shop catalogue"] += found
                    totals["brands read as a catalogue"] += 1
                    totals["with URLs"] += 1
                    log.ok(f"{brand['slug']}: {found} product(s) from the Store API")
                    continue
                log.warn(f"{brand['slug']}: no Store API, crawling instead")

            candidates = discover(
                brand["website"], fetcher, store, brand["slug"], max_pages=args.max_pages
            )
            likely = [item for item in candidates if item.likely][: args.max_pages]
            totals["product URLs"] += len(likely)
            for item in likely:
                by_source[item.source] = by_source.get(item.source, 0) + 1
                handle.write(
                    json.dumps(
                        {
                            "brand_slug": brand["slug"],
                            "brand_name": brand["name"],
                            "url": item.url,
                            "score": item.score,
                            "source": item.source,
                        }
                    )
                    + "\n"
                )
            if likely:
                totals["with URLs"] += 1
                sources = ", ".join(sorted({item.source for item in likely}))
                log.ok(f"{brand['slug']}: {len(likely)} product URL(s) from {sources}")
            else:
                totals["without URLs"] += 1
                empty.append(brand["slug"])
                log.warn(f"{brand['slug']}: no product URL found")

    # The brands that gave nothing are the work list for the next round: each is
    # either a site that needs a rule of its own or a site that is built in the
    # browser and cannot be read this way.
    if empty:
        log.info("no URLs for: " + ", ".join(empty[:40]) + (" ..." if len(empty) > 40 else ""))
    log.summary("Discover", {**totals, **{f"from {k}": v for k, v in by_source.items()}})
    log.ok(f"wrote {output}")


def command_crawl(args) -> None:
    store = DocumentStore(VAR / "documents.sqlite3")
    fetcher = Fetcher(delay=args.delay, obey_robots=not args.ignore_robots)
    rows = [json.loads(line) for line in open(VAR / "urls.jsonl", encoding="utf-8")]
    if args.brand:
        wanted = {value.lower() for value in args.brand}
        rows = [row for row in rows if row["brand_slug"].lower() in wanted]
    platform_by_brand = read_platforms()
    todo = [row for row in rows if args.refresh or not store.has(normalise_url(row["url"]))]
    cached = len(rows) - len(todo)
    log.step(
        f"crawl: {len(todo)} page(s) to fetch, {cached} already stored, "
        f"{args.delay}s between requests"
    )
    if todo:
        # The time is worth printing before the crawl rather than after it: at
        # two seconds for each page one brand is minutes and the whole catalogue
        # is days, and that is a decision to take now, not in six hours.
        minutes = int(len(todo) * args.delay / 60)
        log.info(f"  at this delay that is about {minutes // 60}h{minutes % 60:02d}m")

    progress = log.Progress("pages", total=len(todo))
    current_brand = None
    for row in todo:
        if row["brand_slug"] != current_brand:
            current_brand = row["brand_slug"]
            log.info(f"  {current_brand}")
        url = normalise_url(row["url"])
        response = fetcher.get(url)
        store.put(
            url,
            row["brand_slug"],
            "page",
            response.status,
            response.content_type,
            response.text,
            response.error,
        )
        if response.error:
            progress.add(response.error.split(":")[0][:24])
        elif response.status != 200:
            progress.add(f"HTTP {response.status}")
        else:
            progress.add("ok")
            # Squarespace answers every page with the data behind it. It is one
            # more request, and it gives the article number and the price per
            # variant, which the markup on these sites does not carry.
            if platform_by_brand.get(row["brand_slug"]) == "squarespace":
                twin = platforms_module.squarespace_json_url(url)
                if args.refresh or not store.has(twin):
                    answer = fetcher.get(twin)
                    store.put(
                        twin, row["brand_slug"], "json", answer.status,
                        answer.content_type, answer.text, answer.error,
                    )
    progress.finish()
    if fetcher.refused_by_robots:
        log.warn(f"{fetcher.refused_by_robots} page(s) refused by robots.txt")
    log.summary("Crawl", {"fetched": progress.counts.get("ok", 0), "from cache": cached})


def command_extract(args) -> None:
    # Extraction only reads the stored pages; the one thing it writes to the
    # database is its own cache. Both can therefore be moved off the database,
    # which is what makes the stage runnable on a file system that refuses the
    # locks SQLite needs -- a network share, or a container mount.
    cache = FileCache(VAR / "extractions.jsonl") if args.cache_file else None
    store = DocumentStore(
        VAR / "documents.sqlite3", read_only=args.read_only or bool(cache), cache=cache
    )
    schema = Schema.load(Path(args.schema))
    brands = read_brands(Path(args.brands), [])
    brand_names = {row["slug"]: row["name"] for row in brands}
    brand_homes = {row["slug"]: row["website"] for row in brands}
    # Every brand of the catalogue, also those without a website: a shop sells
    # the products of brands that this pipeline never visits.
    with open(Path(args.brands), newline="", encoding="utf-8") as handle:
        other_brands = OtherBrands(
            (row["slug"], row["name"]) for row in csv.DictReader(handle)
        )
    output = VAR / "candidates.jsonl"
    seen: Dict[str, str] = {}
    written = 0

    only_brand = args.brand[0] if args.brand else None
    mode = "markup" if args.markup_only else "markup+text"

    if args.refresh:
        forgotten = store.forget_extractions(only_brand)
        log.info(f"  {forgotten} cached extraction(s) dropped, everything is read again")

    currency_by_brand: Dict[str, Optional[str]] = {}

    def currency_of(brand_slug: str) -> Optional[str]:
        """The shop's currency, read from the home page that `platforms` stored."""
        if brand_slug not in currency_by_brand:
            home = next(store.documents_of("home", brand_slug), None)
            currency_by_brand[brand_slug] = (
                platforms_module.shopify_currency(home.body) if home and home.ok else None
            )
        return currency_by_brand[brand_slug]

    catalogues = list(store.documents_of("catalog", only_brand))
    woo_catalogues = list(store.documents_of("catalog_woo", only_brand))
    # The pages are NOT read into a list. One store of 12330 pages is several
    # gigabytes of HTML, and holding it made the process be killed by the
    # system -- which loses the output, because what is written is still in the
    # buffer. The pages are streamed, and the count for the progress line is a
    # COUNT rather than a len().
    page_count = store.count_pages(only_brand)
    log.step(
        f"extract: {len(catalogues) + len(woo_catalogues)} shop catalogue(s) "
        f"and {page_count} stored page(s)"
        + (", markup only, no language model" if args.markup_only else "")
    )

    # The URL rules are applied again here, against the pages that are already
    # stored. They will get better after every run, and a better rule must take
    # effect without crawling six hundred sites a second time.
    # The same two passes that `discover` makes, and for the same reason: a site
    # with flat product URLs scores every page below the bar, and applying only
    # the strict rule here would drop pages that the crawl deliberately kept.
    # Without this the two stages disagree and a brand silently yields nothing.
    by_brand: Dict[str, list] = {}
    for brand_slug, url in store.page_index(only_brand):
        if brand_slug in brand_homes:
            by_brand.setdefault(brand_slug, []).append(url)

    strict = []
    for brand_slug, urls in by_brand.items():
        home = brand_homes[brand_slug]
        kept = [url for url in urls if score_url(url, home) >= 2]
        if not kept:
            kept = [url for url in urls if score_url(url, home) >= 1]
            if kept:
                log.info(f"  {brand_slug}: no obvious product path, reading {len(kept)} page(s) anyway")
        strict += kept
    wanted = set(prefer_canonical(strict))
    dropped = page_count - len(wanted)
    if dropped > 0:
        log.info(f"  {dropped} stored page(s) no longer look like a product page")

    progress = log.Progress("pages", total=page_count)
    current_brand = None
    from_catalogue = 0
    reused = 0

    def emit(candidate_json: dict) -> bool:
        """Write one candidate, unless it is a duplicate or out of scope."""
        nonlocal written

        candidate = Candidate(**{
            key: value for key, value in candidate_json.items()
            if key in Candidate.__dataclass_fields__ and key != "provenance"
        })
        candidate.provenance = {
            name: Provenance(**entry)
            for name, entry in (candidate_json.get("provenance") or {}).items()
        }
        if not candidate.name:
            return False
        key = candidate.match_keys[0] if candidate.match_keys else candidate.source_url
        if key in seen:
            return False
        seen[key] = candidate.source_url
        refused = in_scope(candidate, args.keep_conditions, other_brands)
        if refused:
            progress.counts[refused] += 1
            return False
        handle.write(candidate.to_json() + "\n")
        written += 1
        # Written through rather than buffered. A long run that is stopped --
        # by hand, or by the system -- then keeps what it had found, instead of
        # leaving an empty file behind.
        if written % 200 == 0:
            handle.flush()
        return True

    with open(output, "w", encoding="utf-8") as handle:
        # -- the shop catalogues -------------------------------------------
        for catalogue in catalogues:
            if not catalogue.ok:
                continue
            key = store.extraction_key(catalogue, EXTRACTOR_VERSION, mode)
            cached = None if args.refresh else store.cached_extraction(key)
            if cached is None:
                currency = currency_of(catalogue.brand_slug)
                home = catalogue.url.split("/products.json")[0]
                cached = []
                for product in platforms_module.parse_shopify_catalog(catalogue.body):
                    candidate = Candidate(
                        brand_slug=catalogue.brand_slug,
                        source_url=f"{home}/products/{product.get('handle', '')}",
                    )
                    apply_shopify_product(candidate, product, catalogue.url, currency)
                    if candidate.name:
                        cached.append(json.loads(candidate.to_json()))
                store.remember_extraction(key, catalogue, cached)
            else:
                reused += 1
            for candidate_json in cached:
                if emit(candidate_json):
                    from_catalogue += 1
        for catalogue in woo_catalogues:
            if not catalogue.ok:
                continue
            key = store.extraction_key(catalogue, EXTRACTOR_VERSION, mode)
            cached = None if args.refresh else store.cached_extraction(key)
            if cached is None:
                cached = []
                for product in platforms_module.parse_woocommerce_catalog(catalogue.body):
                    candidate = Candidate(
                        brand_slug=catalogue.brand_slug,
                        source_url=product.get("permalink") or catalogue.url,
                    )
                    apply_woocommerce_product(
                        candidate, product, catalogue.url,
                        brand_names.get(catalogue.brand_slug),
                    )
                    if candidate.name:
                        cached.append(json.loads(candidate.to_json()))
                store.remember_extraction(key, catalogue, cached)
            else:
                reused += 1
            for candidate_json in cached:
                if emit(candidate_json):
                    from_catalogue += 1

        store.commit()
        if from_catalogue:
            log.ok(f"{from_catalogue} product(s) read from shop catalogues")

        # -- the pages -----------------------------------------------------
        for document in store.pages(only_brand):
            if document.brand_slug != current_brand:
                current_brand = document.brand_slug
                log.info(f"  {current_brand}")
            if document.brand_slug in brand_homes and document.url not in wanted:
                progress.add("not a product URL")
                continue
            if not document.ok:
                progress.add("not fetched")
                continue
            if document.content_type and "html" not in document.content_type.lower():
                progress.add("not a web page")
                continue

            key = store.extraction_key(document, EXTRACTOR_VERSION, mode)
            cached = None if args.refresh else store.cached_extraction(key)
            if cached is not None:
                reused += 1
                progress.add("ok" if any(emit(item) for item in cached) else "nothing found")
                continue

            candidate = Candidate(brand_slug=document.brand_slug, source_url=document.url)
            brand_name = brand_names.get(document.brand_slug)
            has_markup = apply_markup(candidate, document.body, document.url, brand_name)

            twin = store.get(platforms_module.squarespace_json_url(document.url))
            if twin and twin.ok:
                items = platforms_module.parse_squarespace(twin.body)
                if items:
                    apply_squarespace_item(candidate, items[0], twin.url, brand_name)
                    has_markup = True

            text = page_text(document.body, limit=args.page_chars)
            needs_text = not has_markup or not candidate.sub_category_slug
            usable = True
            if needs_text and not args.markup_only:
                try:
                    answer = call_model(
                        build_prompt(brand_name or document.brand_slug, text, schema)
                    )
                except Exception as error:  # one page must not stop a run
                    candidate.warnings.append(f"extraction failed: {error}")
                    log.error(f"{document.url}: {error}")
                    answer = {}
                usable = apply_text_extraction(candidate, answer, text, document.url, schema)
            elif args.markup_only and not has_markup:
                # Without the text extractor the only evidence for a page with
                # no markup is its title, and a category page has one as well.
                usable = False

            found = [json.loads(candidate.to_json())] if usable and candidate.name else []
            store.remember_extraction(key, document, found)
            if not found:
                progress.add("no markup" if args.markup_only else "not a product page")
                continue
            progress.add("ok" if emit(found[0]) else "duplicate")
        store.commit()

    progress.finish()
    if reused:
        log.ok(f"{reused} document(s) were unchanged and were not read again")
    log.summary(
        "Extract",
        {
            "candidates written": written,
            "of those, from a shop catalogue": from_catalogue,
            "reused from the last run": reused,
            **{name: count for name, count in sorted(progress.counts.items()) if name != "ok"},
        },
    )
    log.ok(f"wrote {output}")


def command_classify(args) -> None:
    """Give the candidates their sub categories, in batches, from their names.

    Reads candidates.jsonl and writes it back with `sub_category_slugs` filled
    in. Nothing else is touched, and nothing is promoted: the slugs reach the
    catalogue as a proposal in the staging table, which a person still approves.

    Every answer is kept in var/classifications.jsonl against the product it was
    read from, so a second run costs nothing and a stopped run loses nothing.
    """
    schema = Schema.load(Path(args.schema))
    known = set(schema.sub_category_slugs)
    brand_names = {row["slug"]: row["name"] for row in read_brands(Path(args.brands), [])}

    path = VAR / "candidates.jsonl"
    rows = [json.loads(line) for line in open(path, encoding="utf-8")]
    cache = FileCache(VAR / "classifications.jsonl")

    todo = [
        row for row in rows
        if not row.get("sub_category_slugs") and cache.get(classifier.cache_key(row)) is None
    ]
    if args.limit:
        todo = todo[: args.limit]

    log.step(
        f"classify: {len(rows)} candidate(s), {len(todo)} to read, "
        f"{args.batch} per request, model {classifier.MODEL}"
    )
    if args.dry_run:
        log.info(f"  that is about {-(-len(todo) // args.batch)} request(s). Nothing was sent.")
        return

    progress = log.Progress("products", total=len(todo))
    tokens_in = tokens_out = 0

    for start in range(0, len(todo), args.batch):
        batch = todo[start : start + args.batch]
        items = [
            {
                "brand": brand_names.get(row["brand_slug"], row["brand_slug"]),
                "brand_slug": row["brand_slug"],
                "source_category": row.get("source_category"),
                "name": row.get("name"),
            }
            for row in batch
        ]
        try:
            answer = classifier.call_model(
                classifier.build_prompt(items, schema.sub_categories)
            )
        except Exception as error:  # one batch must not stop a run
            log.error(f"batch of {len(batch)} failed: {error}")
            progress.add("request failed", len(batch))
            continue

        usage = answer.get("usage") or {}
        tokens_in += usage.get("input_tokens", 0)
        tokens_out += usage.get("output_tokens", 0)
        results = classifier.clean_results(answer.get("answer"), items, known)

        for index, row in enumerate(batch):
            result = results.get(index)
            if result is None:
                progress.add("no answer")
                continue
            cache.put(classifier.cache_key(row), row.get("source_url", ""), row["brand_slug"],
                      [result])
            progress.add("ok" if result["slugs"] or result["out_of_scope"] else "unsure")
        cache.commit()
    progress.finish()

    # Write every kept answer onto the candidates, from the cache, so that a run
    # which was stopped halfway still writes what it had read.
    classified = refused = 0
    with open(path, "w", encoding="utf-8") as handle:
        for row in rows:
            kept = cache.get(classifier.cache_key(row))
            if kept:
                result = kept[0]
                if result.get("out_of_scope"):
                    row["warnings"] = (row.get("warnings") or []) + [
                        "read as out of scope by the classifier"
                    ]
                    refused += 1
                elif result.get("slugs"):
                    row["sub_category_slugs"] = result["slugs"]
                    row.setdefault("provenance", {})["sub_category_slugs"] = {
                        "source": "llm", "url": row.get("source_url", ""),
                        "snippet": "classified from the product name", "confidence": 0.6,
                    }
                    classified += 1
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")

    log.summary(
        "Classify",
        {
            "candidates with sub categories": classified,
            "read as out of scope": refused,
            "left unclassified": len(rows) - classified - refused,
            "tokens in / out": f"{tokens_in} / {tokens_out}",
        },
    )
    log.ok(f"wrote {path}")


# The checks are a decision, not an output: they were expensive to make, they
# are the same in every environment, and they are worth reading as a diff. So
# they live in the repository beside the category mappings, and `var/` keeps
# only what a crawl can make again. A file in `var/` is still read when one is
# there, for a check that has not been committed yet.
VALIDATIONS_IN_REPO = HERE.parent.parent / "db" / "import_validations.jsonl"


def command_validations(args) -> None:
    """Write the verdicts of a second reading onto the candidates.

    The verdicts are keyed by the product rather than by the row, so a check
    survives both a re-extract and a re-crawl -- and a move to another machine.
    """
    path = VAR / "candidates.jsonl"
    checks = validations_module.load(VALIDATIONS_IN_REPO)
    local = validations_module.load(VAR / "validations.jsonl")
    if local:
        log.info(f"  {len(local)} check(s) from var/ on top of {len(checks)} from db/")
        checks.update(local)
    log.step(f"validations: {len(checks)} check(s) on file")
    if not checks:
        log.warn("nothing to apply")
        return

    counts: Dict[str, int] = {}
    matched = 0
    cleared = 0
    dated = 0
    rows = [json.loads(line) for line in open(path, encoding="utf-8")]
    with open(path, "w", encoding="utf-8") as handle:
        for row in rows:
            key = validations_module.key_for(
                row["brand_slug"], validations_module.source_name(row), row.get("source_category")
            )
            check = checks.get(key)
            if check:
                verdict = validations_module.apply_to(row, check)
                counts[verdict] = counts.get(verdict, 0) + 1
                matched += 1
            if validations_module.drop_model_equal_to_name(row):
                cleared += 1
            if validations_module.mark_discontinued(row):
                dated += 1
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")

    log.summary(
        "Validations",
        {**counts, "checks that matched no candidate": len(checks) - matched,
         "model numbers that only repeated the name": cleared,
         "marked discontinued by the shop's category or title": dated},
    )
    log.ok(f"wrote {path}")


def read_platforms() -> Dict[str, str]:
    """What `platforms` found, by brand slug. Empty when it has not been run."""
    path = VAR / "platforms.csv"
    if not path.exists():
        return {}
    with open(path, newline="", encoding="utf-8") as handle:
        return {row["slug"]: row["platform"] for row in csv.DictReader(handle)}


def command_platforms(args) -> None:
    """One request for each brand: which builder, and does it sell on the site.

    This answers the question that decides everything else -- how much of the
    catalogue can be read from markup alone -- for a few thousand requests
    rather than for a crawl of every site. The builder alone does not answer it:
    Shopify, Squarespace, Wix and WooCommerce all write a product object, but
    only on the pages of a shop. A brand that sells through dealers has product
    pages and no markup, whatever it is built with.
    """
    brands = read_brands(Path(args.brands), args.brand, args.platform)
    fetcher = Fetcher(delay=args.delay, obey_robots=not args.ignore_robots)
    store = DocumentStore(VAR / "documents.sqlite3")
    output = VAR / "platforms.csv"

    log.step(f"platforms: {len(brands)} brand(s), one request each")
    counts: Dict[str, int] = {}
    shops = 0
    with_markup = 0
    progress = log.Progress("brands", total=len(brands))

    with open(output, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["slug", "name", "website", "platform", "sells_on_site", "product_markup"])
        for brand in brands:
            response = fetcher.get(brand["website"])
            store.put(
                brand["website"], brand["slug"], "home", response.status,
                response.content_type, response.text, response.error,
            )
            if response.error or not response.text:
                name = "unreachable"
                sells = markup = False
                progress.add(response.error or "empty")
            else:
                name = platforms_module.detect(response.text)
                sells = platforms_module.has_shop(response.text)
                markup = platforms_module.has_product_markup(response.text)
                progress.add("ok")
            counts[name] = counts.get(name, 0) + 1
            shops += bool(sells)
            with_markup += bool(markup)
            writer.writerow(
                [brand["slug"], brand["name"], brand["website"], name,
                 "yes" if sells else "no", "yes" if markup else "no"]
            )
            log.detail(f"{brand['slug']}: {name}{', shop' if sells else ''}")
    progress.finish()

    ordered = dict(sorted(counts.items(), key=lambda item: -item[1]))
    log.summary("Builders", ordered)
    log.summary(
        "What that means",
        {
            "brands that sell on their own site": shops,
            "home page already carries product markup": with_markup,
            "brands checked": len(brands),
        },
    )
    log.ok(f"wrote {output}")


def in_scope(candidate, keep_conditions: bool, other_brands=None) -> Optional[str]:
    """Why this candidate is not written, or None when it is.

    A shop sells much that a hi-fi catalogue does not hold, and every one of
    those items would otherwise be refused by hand in the review. The refusal is
    recorded as a reason and counted, and the document store keeps the answer it
    came from, so a rule that is wrong is undone by extracting again.
    """
    reason = out_of_scope(
        candidate.name, candidate.source_category, candidate.source_url, candidate.brand_slug
    )
    if reason:
        return reason
    if other_brands is not None and other_brands.of(candidate.name, candidate.brand_slug):
        # The site sells it, but another brand makes it. See OtherBrands.
        return "a product of another brand"
    state = condition(candidate.name, candidate.source_category) or shop_state(candidate.name)
    if state:
        if keep_conditions:
            candidate.warnings.append(f"sold as {state!r}: a condition, not a product")
            return None
        # The same product again, in a state the catalogue does not have. One
        # shop's outlet alone was 2657 of 14792 items in the first full run.
        return f"sold as {state!r}"
    return None


FIELDS = [
    "brand_slug", "name", "variant_name", "model_no", "sub_category_slug",
    "source_category", "price", "price_currency", "release_year",
    "discontinued", "score", "source_url",
]


def _catalog_descriptions(store, brand_slug: str) -> Dict[str, str]:
    """{product path: description HTML} from the shop feeds stored for a brand.

    Most candidates were read from a shop feed (Shopify products.json, the
    WooCommerce Store API, Squarespace JSON), and their own pages were never
    fetched. The feed carries the product description, and that is where many
    shops print the specification list.
    """
    from urllib.parse import urlparse

    found: Dict[str, str] = {}
    rows = store.conn.execute(
        "SELECT url, kind, body FROM documents WHERE brand_slug = ? "
        "AND kind IN ('catalog', 'catalog_woo', 'json') AND body IS NOT NULL",
        (brand_slug,),
    )
    for url, kind, body in rows:
        try:
            data = json.loads(body)
        except (TypeError, ValueError):
            continue
        if kind == "catalog" and isinstance(data, dict):
            for product in data.get("products") or []:
                if isinstance(product, dict) and product.get("handle"):
                    found[f"/products/{product['handle']}"] = product.get("body_html") or ""
        elif kind == "catalog_woo" and isinstance(data, list):
            for product in data:
                if isinstance(product, dict) and product.get("permalink"):
                    path = urlparse(product["permalink"]).path.rstrip("/")
                    found[path] = (product.get("description") or "") + (product.get("short_description") or "")
        elif kind == "json" and isinstance(data, dict):
            items = [data["item"]] if isinstance(data.get("item"), dict) else data.get("items") or []
            for item in items:
                if isinstance(item, dict) and item.get("fullUrl"):
                    found[item["fullUrl"].rstrip("/")] = item.get("body") or ""
    return found


def command_specs(args) -> None:
    """Read the specification lists of the stored pages into custom attributes.

    It runs after `validations`, because an attribute is written only when it
    applies to the candidate's sub categories, and those are final only then.
    Rows read as out of scope are not read. A value that a better source gave
    already is kept. No page is fetched: only the stored pages are read.
    """
    from . import specs as specs_module

    schema = json.loads(Path(args.schema).read_text(encoding="utf-8"))
    scopes = {
        attribute["label"]: set(attribute.get("sub_categories") or [])
        for attribute in schema.get("custom_attributes", [])
    }
    only = {slug.strip() for slug in (args.only or "").split(",") if slug.strip()}
    store = DocumentStore(VAR / "documents.sqlite3", read_only=True)
    path = VAR / "candidates.jsonl"
    rows = [json.loads(line) for line in open(path, encoding="utf-8")]

    from urllib.parse import urlparse

    feeds: Dict[str, Dict[str, str]] = {}
    mapped = specs_module.mapped_sub_categories(HERE.parent.parent / "db" / "import_category_mappings.yml")
    read = found = 0
    counts: Dict[str, int] = {}
    samples: List[str] = []
    for row in rows:
        if only and row["brand_slug"] not in only:
            continue
        if row.get("validation_verdict") == "out_of_scope":
            continue
        slugs = row.get("sub_category_slugs") or []
        if not slugs and row.get("source_category"):
            word = row["source_category"].lower()
            slugs = mapped.get((row["brand_slug"], word)) or mapped.get((None, word)) or []
        document = store.get(row["source_url"])
        if document and document.body:
            html = document.body
        else:
            brand = row["brand_slug"]
            if brand not in feeds:
                feeds.clear()  # one brand at a time: the rows come grouped by brand
                feeds[brand] = _catalog_descriptions(store, brand)
            html = feeds[brand].get(urlparse(row["source_url"]).path.rstrip("/"))
        if not html:
            continue
        read += 1
        text = page_text(html, limit=args.page_chars)

        # A candidate without sub categories keeps every value read: the
        # person who gives it a sub category then finds them filled in, and
        # the product form shows only the ones that apply.
        def applies(label, slugs=slugs):
            return not slugs or bool(scopes.get(label, set()) & set(slugs))

        values = specs_module.read_specs(text, slugs, applies)
        if not values:
            continue
        found += 1
        attributes = row.get("custom_attributes") or {}
        provenance = row.setdefault("provenance", {})
        for label, (value, snippet) in values.items():
            key = f"custom_attributes.{label}"
            existing = provenance.get(key) or {}
            if label in attributes and existing.get("confidence", 0) >= 0.85:
                continue
            attributes[label] = value
            provenance[key] = {
                "source": specs_module.SOURCE,
                "url": row["source_url"],
                "snippet": snippet,
                "confidence": 0.85,
            }
            counts[label] = counts.get(label, 0) + 1
            if len(samples) < args.samples:
                samples.append(f"{row['brand_slug']} | {row.get('name')} | {label} = "
                               f"{json.dumps(value, ensure_ascii=False)} <- {snippet!r}")
        row["custom_attributes"] = attributes

    if not args.dry_run:
        with open(path, "w", encoding="utf-8") as handle:
            for row in rows:
                handle.write(json.dumps(row, ensure_ascii=False) + "\n")
    for line in samples:
        log.info("  " + line)
    log.summary("Specifications", {"pages read": read, "pages with values": found, **counts})
    log.ok("dry run, nothing written" if args.dry_run else f"wrote {path}")


def command_report(args) -> None:
    log.step("report")
    rows = [json.loads(line) for line in open(VAR / "candidates.jsonl", encoding="utf-8")]
    rows.sort(key=lambda row: (row["brand_slug"], -row["score"], row.get("name") or ""))
    output = VAR / "candidates.csv"
    with open(output, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(FIELDS + ["variants", "sources", "warnings"])
        for row in rows:
            sources = ",".join(
                sorted({entry["source"] for entry in row["provenance"].values()})
            )
            writer.writerow(
                [row.get(name) for name in FIELDS]
                + [
                    len(row.get("variants") or []),
                    sources,
                    "; ".join(row.get("warnings") or []),
                ]
            )
    # The three numbers that decide what to do next: how much is ready to
    # review, how much needs a rule, and how much of the catalogue's own shape
    # the extraction actually filled in.
    with_category = sum(1 for row in rows if row.get("sub_category_slug"))
    with_price = sum(1 for row in rows if row.get("price"))
    from_markup = sum(
        1 for row in rows
        if any(entry["source"] in ("jsonld", "products_json")
               for entry in row["provenance"].values())
    )
    good = sum(1 for row in rows if row["score"] >= 0.6)
    log.summary(
        "Candidates",
        {
            "total": len(rows),
            "score 0.6 or better": good,
            "with a sub category": with_category,
            "with a price": with_price,
            "touched by machine readable markup": from_markup,
            "brands": len({row["brand_slug"] for row in rows}),
        },
    )
    log.ok(f"wrote {output} ({len(rows)} rows)")


def add_common(parser, suppress: bool) -> None:
    """The options that every stage takes.

    They are declared twice: once on the main parser with real defaults, and
    once on each stage. argparse otherwise accepts them only in front of the
    stage name, so `... --delay 1 discover --brand rega` fails while
    `... --brand rega --delay 1 discover` works -- and the error names the
    argument rather than the position, which is not much help. On the stages the
    defaults are suppressed, so an option that is not written there does not
    overwrite the one in front.
    """
    def default(value):
        return argparse.SUPPRESS if suppress else value

    parser.add_argument("--brands", default=default(str(VAR / "brands.csv")))
    parser.add_argument(
        "--brand", action="append", default=default([]),
        help="limit to this brand slug; may be given many times",
    )
    parser.add_argument(
        "--platform", action="append", default=default([]),
        help="limit to the brands that `platforms` found on this builder, "
             "for example --platform shopify",
    )
    parser.add_argument("--delay", type=float, default=default(2.0),
                        help="seconds between requests")
    parser.add_argument("--ignore-robots", action="store_true", default=default(False))
    parser.add_argument("--max-pages", type=int, default=default(1500))
    parser.add_argument("-v", "--verbose", action="store_true", default=default(False),
                        help="one line per page")
    parser.add_argument("-q", "--quiet", action="store_true", default=default(False),
                        help="warnings and errors only")


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(prog="brand-importer")
    add_common(parser, suppress=False)
    stage_options = argparse.ArgumentParser(add_help=False)
    add_common(stage_options, suppress=True)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("platforms", parents=[stage_options]).set_defaults(run=command_platforms)
    sub.add_parser("discover", parents=[stage_options]).set_defaults(run=command_discover)
    crawl = sub.add_parser("crawl", parents=[stage_options])
    crawl.add_argument("--refresh", action="store_true", help="fetch pages that are already stored")
    crawl.set_defaults(run=command_crawl)
    extract = sub.add_parser("extract", parents=[stage_options])
    extract.add_argument("--schema", default=str(HERE / "schema" / "product_schema.json"))
    extract.add_argument("--markup-only", action="store_true", help="no language model")
    extract.add_argument("--page-chars", type=int, default=12000)
    extract.add_argument(
        "--cache-file", action="store_true",
        help="keep the extraction cache in var/extractions.jsonl instead of in the "
             "database, and open the database read-only",
    )
    extract.add_argument(
        "--read-only", action="store_true",
        help="do not write to the database at all (no cache is kept)",
    )
    extract.add_argument(
        "--refresh", action="store_true",
        help="read every stored document again, ignoring what was extracted before",
    )
    extract.add_argument(
        "--keep-conditions", action="store_true",
        help="also write the items a shop sells as outlet, B-stock or used",
    )
    extract.set_defaults(run=command_extract)
    classify = sub.add_parser("classify", parents=[stage_options])
    classify.add_argument("--schema", default=str(HERE / "schema" / "product_schema.json"))
    classify.add_argument("--batch", type=int, default=40, help="products per request")
    classify.add_argument("--limit", type=int, help="stop after this many products")
    classify.add_argument("--dry-run", action="store_true", help="say how much, send nothing")
    classify.set_defaults(run=command_classify)
    sub.add_parser("validations", parents=[stage_options]).set_defaults(run=command_validations)
    specs = sub.add_parser("specs", parents=[stage_options])
    specs.add_argument("--schema", default=str(HERE / "schema" / "product_schema.json"))
    specs.add_argument("--only", help="brand slugs, separated by commas")
    specs.add_argument("--page-chars", type=int, default=60000)
    specs.add_argument("--samples", type=int, default=0, help="print this many values read")
    specs.add_argument("--dry-run", action="store_true", help="read and count, write nothing")
    specs.set_defaults(run=command_specs)
    sub.add_parser("report", parents=[stage_options]).set_defaults(run=command_report)

    args = parser.parse_args(argv)
    log.configure(verbose=args.verbose, quiet=args.quiet)
    VAR.mkdir(parents=True, exist_ok=True)
    log.info(f"working directory {VAR}")
    try:
        args.run(args)
    except KeyboardInterrupt:
        # A crawl is stopped by hand often, and everything fetched so far is in
        # the store. Say that, rather than printing a stack trace that reads
        # like a fault.
        log.warn("stopped. The pages already fetched are kept; run the same command again.")
        sys.exit(130)


if __name__ == "__main__":
    main()
