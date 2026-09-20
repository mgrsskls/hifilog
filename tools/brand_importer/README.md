# Brand importer

This tool reads the websites of the brands in the catalogue and writes candidate
products. It does not write to the database. It is outside the Rails application
on purpose: it is slow, it speaks to the network, and it must be possible to run
it again and again without a deploy.

## What it is for

The catalogue must grow faster than a person can type. The manufacturer's own
site is the best source there is for products still made: it is authoritative,
it is legal to read, and there are approximately 600 of them in the brand list.

## What it does not do

- It does not write a product. It writes candidates with a source for each
  field. A person or a rule promotes them.
- It does not read other databases. Only the site of the brand itself.
- It does not invent. A field that the page does not state stays empty.

## The four stages

Each stage writes a file and reads the file of the stage before it. Any stage
can be run again alone. This is important for `extract`: the extraction rules
will change many times, and a change must not cost a second crawl.

```
discover  ->  var/urls.jsonl         which URLs are products
crawl     ->  var/documents.sqlite3  the pages themselves, unchanged
extract   ->  var/candidates.jsonl   candidates with provenance per field
report    ->  var/candidates.csv     a sheet to look through
```

## How to run it

Write the two inputs from the database first. They must be written again when a
sub category, an attribute or a brand website changes:

```sh
bin/rails import:brands > tools/brand_importer/var/brands.csv
bin/rails import:schema > tools/brand_importer/schema/product_schema.json
```

Then run the stages. Start with a small number of brands:

```sh
cd tools/brand_importer
python3 -m hifilog_import.cli platforms            # one request per brand
python3 -m hifilog_import.cli discover --brand rega --brand accuphase
python3 -m hifilog_import.cli crawl --brand rega --brand accuphase
export ANTHROPIC_API_KEY=...
python3 -m hifilog_import.cli extract
python3 -m hifilog_import.cli report
```

Every option may be written before or after the stage name, so
`--delay 1 discover` and `discover --delay 1` both work.

`--platform` selects the brands that `platforms` found on one builder. This is
how you take the cheap part of the catalogue first:

```sh
python3 -m hifilog_import.cli discover --platform shopify --delay 1
python3 -m hifilog_import.cli extract --markup-only
python3 -m hifilog_import.cli report
```

**Extraction is not repeated.** Every answer is kept against the digest of the
document it came from and the version of the extractor that read it, so a second
run reads only what is new or what has changed. The output file is still
complete: it is rebuilt from what was kept plus what is new. A page that has not
changed, read by the same rules, gives the same candidates — and with a language
model in the path, repeating that work is not slow, it is paid for twice.
`--refresh` reads everything again. `EXTRACTOR_VERSION` in `cli.py` is raised
whenever a rule changes what an answer would be, which invalidates the kept
answers by itself.

`extract --markup-only` runs without a language model and without cost. It gives
fewer fields, but it shows immediately how much of a site states its products in
machine readable form.

Python 3.9 or later. No packages to install: the standard library only.

## What each site builder gives

Most brand sites are built with a small number of systems, and each one states
a different amount in machine readable form. This is what decides whether a
brand costs nothing or costs a language model call for each page.

| Builder     | Product markup            | More than markup                        |
| ----------- | ------------------------- | --------------------------------------- |
| Shopify     | yes, on product pages     | `/products.json`: **the whole catalogue** |
| Squarespace | yes, on shop pages        | `?format=json` on any page: the item data |
| Wix         | yes, on Wix Stores pages  | product pages sit under `/product-page/`  |
| WooCommerce | **no, in practice**       | `/wp-json/wc/store/v1/products`: the catalogue |
| Webflow, Jimdo, Weebly | only if hand added | —                                   |
| Hand built  | rarely                    | —                                        |

Three of these are worth the extra step, and the importer takes it:

- **Shopify is not crawled at all.** The shop answers `/products.json` with its
  products, 250 at a time, in the shop software's own structure. One request
  therefore replaces 250 page fetches and 250 extractions, and what comes back
  is better than the pages carry: every version with its article number and its
  price. `discover` reads the catalogue for a brand that `platforms` found to be
  Shopify, writes nothing to `urls.jsonl`, and `crawl` has nothing to do for it.
  If the shop does not answer, the ordinary discovery runs instead.
  The one thing `products.json` does not carry is the currency; the shop writes
  that into its own pages, and it is read from the home page that `platforms`
  already stored, so it costs no request.

- **Squarespace** answers every page with the data behind it when `?format=json`
  is added. That is a documented feature of the platform. It gives what the
  markup on these sites leaves out: the article number and the price of each
  variant. The crawl fetches it for a brand that `platforms` found to be on
  Squarespace, and the answer is trusted like the markup but never overwrites
  it. Squarespace says this is not a replacement for its API and may change, so
  it is an addition, never the only source.
- **WooCommerce is read through its Store API**, and not through its pages. The
  first sample found no product markup on these shops at all: the SEO plugin had
  replaced it with BreadcrumbList, ItemPage, Organization and WebSite, so 382
  product pages of one shop gave nothing. `/wp-json/wc/store/v1/products` is the
  read side of the shop's own software, public and without a key, and it gives
  name, text, article number, price, currency, images and the shop's category.
  The price comes in the smallest unit of the currency with its exponent beside
  it, so 345000 with `currency_minor_unit: 2` is 3450.00 — reading it without
  the exponent would list a 3450 euro amplifier at 345000.
- **Wix** writes a product object into the pages of a Wix Stores shop. Wix
  states that it does this for store product pages by default. Those pages all
  live under `/product-page/`, which the URL rules now know.

**The builder alone does not predict the data.** Every one of these systems
writes a product object *only on the pages of a shop*. A brand that shows its
products but sells through dealers -- which is most of hi-fi -- has a page for
each product and no markup anywhere. That is why `platforms` reports three
things and not one: the builder, whether the site sells, and whether a product
object is present at all.

## What you see while it runs

Every stage writes to **stderr**, so `report > file` and a pipe still work while
the log is on the screen. There is one line for each brand, a progress line that
replaces itself on a terminal, and a table at the end:

```
0:00:04 discover: 5 brand(s), 2.0s between requests
0:00:04 [1/5] rega http://rega.co.uk
0:00:05   robots.txt names 1 sitemap(s)
0:00:11   sitemaps gave 412 candidate URL(s)
0:00:11 ok rega: 118 product URL(s) from sitemap
0:00:12 [2/5] accuphase https://www.accuphase.com
0:00:14 warning accuphase: no sitemap and no shop list, walking the links

Discover
  brands        5
  with URLs     4
  without URLs  1
  product URLs  392
  from sitemap   392
```

Three flags control this:

- `-v`, `--verbose` — one line for each page: the URL, the answer, the size, the
  time, and for each candidate its name, sub category and score. Use it for one
  brand, not for six hundred.
- `-q`, `--quiet` — warnings and errors only.
- Nothing — one line for each brand, and a progress line during long steps.

`crawl` prints how long the run will take **before** it starts, because at two
seconds per page one brand is minutes and the whole catalogue is days. Ctrl-C is
safe at any moment: the pages already fetched stay in the store, and the same
command continues where it stopped.

The table at the end of `extract` is the important one. It does not say how many
pages were read but why the others were not written:

```
Extract
  candidates written    2874
  duplicate              126
  no markup               44
  not a product page      98
  no name                 28
```

`report` ends with the numbers that decide the next step: how many candidates
have a sub category, how many have a price, and how many were touched by machine
readable markup at all. The last number tells you what a language model is
costing you, and for which brands.

## How a field is decided

Extraction goes from the most reliable source to the least reliable one, and a
better source is never overwritten by a worse one:

| Source           | Confidence | What it is                                  |
| ---------------- | ---------- | ------------------------------------------- |
| `products_json`  | 0.95       | the shop software's own product list        |
| `jsonld`         | 0.95       | a schema.org Product object in the page      |
| `microdata`      | 0.9        | Open Graph tags                              |
| `llm`            | 0.6        | read out of the text of the page             |
| `url`            | 0.4        | taken from the address                       |
| `heuristic`      | 0.3        | the page title, and similar guesses          |

**Specifications are read from the specification list (`specs`).** Many brands
print the technical data as pairs: "Frequency Response: 40 - 20.000 Hz",
"Weight: 32 kg / 62 lbs each". The `specs` step reads such pairs from the stored
page, or from the product description in the shop feed when the page itself was
not fetched, and writes them as custom attributes: frequency response,
loudspeaker and headphone sensitivity, nominal and minimum impedance, weight,
dimensions and amplifier output power. It uses no language model, and each value
keeps the words it was read from (source `spec_list`). A doubtful value is left
out: no unit, a range or a choice where one value is expected ("4-8 Ω", "98/102
dB"), a weight per pair or for shipping, dimensions without a stated order
("W x H x D"). An attribute is written only when it applies to the candidate's
sub categories, which is why the step runs after `validations`. `--dry-run`
counts without writing, `--only` limits it to some brands, and `--samples N`
prints values with their source text.

**The description is never taken.** A shop's text is marketing copy, and the
description of a catalogue product is written by people. No extractor fills
the field, even when the page states one (`NOT_TAKEN` in `candidates.py`), and
the text extractor does not ask for one. The field stays on the staging row so
that a person can write it in the review screen.

## Why the values can be trusted

A language model reads a page well and invents a value when it is asked in the
wrong way. Four rules answer that, and three of them are checks in code rather
than sentences in the prompt:

1. **The model can only write fields that this catalogue has.** The field list
   comes from `import:schema`, so an unknown sub category or an option that is
   not offered is refused.
2. **Every field is optional, and empty is a correct answer.** An empty field
   costs a review some seconds. A wrong field costs the trust of the user who
   finds it, and nobody will know which other products are wrong.
3. **Every value must be quoted from the page.** The quotation is searched for
   in the page text, without spaces and without case. A value whose quotation is
   not there is dropped and a warning is recorded.
4. **A page is one product or it is not a product.** A category page returns
   `is_product: false` instead of a guess.

`tests/test_pipeline.py` has a test for each of these. If a rule is removed, a
test fails.

## Politeness

The crawler speaks for hifilog, and a site owner must be able to identify it and
to stop it. It obeys `robots.txt`, including `Crawl-delay`. It makes one request
at a time for each host with a delay of two seconds by default. Its user agent
names the site and an address. `--ignore-robots` exists for a site that you own
and for a test; it must not be used on a brand site.

## What `var/` holds

`var/` is the work of a crawl. It is gitignored, it can be deleted at any time,
and everything in it can be made again from the brand sites.

| File                 | What it is                                          |
| -------------------- | --------------------------------------------------- |
| `brands.csv`         | the input, written by `bin/rails import:brands`      |
| `validations.jsonl`  | checks not yet committed; the committed ones live in `db/` |
| `platforms.csv`      | the builder of each brand site, from `platforms`     |
| `urls.jsonl`         | the product URLs of each brand, from `discover`      |
| `documents.sqlite3`  | every page as it came, the expensive part            |
| `candidates.jsonl`   | the candidates with provenance, from `extract`       |
| `candidates.csv`     | the same, as a sheet, from `report`                  |

Keep `documents.sqlite3`. Extraction reads from it, so a better rule or a better
prompt costs nothing but the extraction. Delete it only to crawl a site again
from the beginning. `HIFILOG_IMPORT_VAR` moves the whole directory; use it to put
the store on a local disk, because some network and container mounts refuse the
file locks that SQLite needs.

`discover` only replaces the rows of the brands in the run. A run for one brand
does not delete the URLs of the others.

## What a crawl of a real site taught the rules

These all come from the first crawl of two sites, and each is now a test:

- **A list page carries a product object.** A Shopify collection page has the
  JSON-LD of the first product on it, so a category page entered the candidates
  under a product name. `/collections/x` is therefore refused, and
  `/collections/x/products/y` is not.
- **Translations triple the work.** The same shop answered under `/`, `/en-mx/`,
  `/es-mx/` and `/fr/`. Fourteen of fifteen products were read from the Mexican
  storefront, with its prices in dollars, while the site's own pages were never
  read. Only one language of each product is crawled now, and the version
  without a language prefix wins. On the same two sites this took the pages from
  249 to 69.
- **An older site has no directories.** `support.html` and `history.html` sit
  beside the product pages, so a segment is compared without its file extension.
- **A shop sells states that a catalogue does not have.** "B-Stock:" and "Show
  Model:" are marked as a warning rather than refused: a small brand sometimes
  sells only in this way, and that is a decision for the review.

The URL rules are applied again by `extract`, against the pages already stored.
A rule that gets better therefore takes effect without crawling anything twice.

## Classifying (`classify`)

The shop's own word answers part of the catalogue and never the rest: thousands
of candidates carry no category at all, and the words that remain name two
things or five. What is left is a question about one product -- "bookshelf or
floorstander?" -- and only the product can answer it.

```sh
export ANTHROPIC_API_KEY=...
python3 -m hifilog_import.cli classify --dry-run          # how many requests, sends nothing
python3 -m hifilog_import.cli classify --limit 200        # a first batch, to look at
python3 -m hifilog_import.cli classify                    # the rest
```

It reads `candidates.jsonl` and writes it back with `sub_category_slugs` filled
in, 40 products per request, name and the shop's word only -- no page text, so
the requests are small. Every answer is kept in `var/classifications.jsonl`
against the product it was read from, so a second run costs nothing and a
stopped run loses nothing. `HIFILOG_IMPORT_MODEL` chooses the model; the default is `claude-sonnet-5`, and
`claude-haiku-4-5-20251001` is the cheaper choice for work this short.
A model id that does not exist is answered with HTTP 400, and the message
now carries the API's own words rather than only the status.

The same three rules as everywhere else:

1. **Only slugs this catalogue defines.** The list comes from `import:schema`;
   anything else in an answer is dropped in silence.
2. **An empty answer is a correct answer.** "Model One", "Universal", "Add On"
   say nothing, and unsure is worth more than a guess a person must later find
   and undo.
3. **Nothing is promoted by this.** A slug written here is a proposal in the
   staging table. A person still approves the product.

An answer may name more than one category, because a product can be more than
one. Two are named only when the product really is both -- not when the
classifier cannot choose, which is an empty answer.

A feature is not a second category. A DAC with a headphone output or a volume
control stays `dacs` only when its maker lists it and names it as a DAC (the
Benchmark DAC3, the AudioQuest DragonFly). It gets `headphone-amplifiers` as
well only when the maker also calls it a headphone amplifier ("Fosi K7 Desktop
DAC Headphone Amplifier"). A headphone output is a property of the DAC, not a
category.

`rake import:load` writes the proposal into `sub_category_ids`, and only for a
row that has none: a mapping or a person already decided the others.

## What a shop sells that this catalogue does not hold

A brand's shop is not a product catalogue. The first run over 128 Shopify shops
gave 14792 items, and a large part of them were never going to be products
here: repair plans, gift cards, spare feet, T-shirts, records, and the same
speaker again as a returned unit.

`extract` refuses those by name and by the shop's own category, and counts each
reason. On that run:

```
a recording, not equipment   424
a payment, not a product     189
a service, not a product     146
a part, not a product         43
merchandise, not equipment    38
sold as 'outlet'            2657
sold as 'refurbished' etc.   279
```

The conditions are counted apart from the rest because they are real products,
only sold in a state the catalogue does not have -- one shop's outlet alone was
2657 items, all of them the same speakers it already lists. `--keep-conditions`
writes them with a warning instead of refusing them.

The test is deliberately narrow: whole words only, in the name and the shop's
category, and anything it is unsure about passes. A false refusal hides a real
product and nobody notices; a false pass costs one second in the review. Nothing
is lost either way, because the document store holds every answer and `extract`
can be run again.

### Ranges of a brand that are out of scope

Some brands sell home hi-fi and other gear in one shop, under the same shop
category. Only the range name separates them, and a range name means something
only inside its brand. `BRAND_RANGES_OUT_OF_SCOPE` in `hifilog_import/scope.py`
lists these ranges per brand, with what they are:

- **Car or marine audio:** the car ranges of Earthquake (SWS, TNT, Tremor, Under-the-Seat).
- **DJ gear:** the Earthquake DJ range, and Ortofon's DJ cartridges (Concorde
  MKII, Q.bert, Scratch, Nightclub, Digitrack, OM Pro S, VNL), and Grado's DJ200i. "Concorde Music" is a hi-fi
  cartridge and stays.

`BRANDS_IGNORED_FOR_NOW` sets a whole brand aside until its ranges are sorted
(Cerwin-Vega).

### Products of another brand

Many brands also run a shop, and a shop also sells the products of other brands:
Summit Hi-Fi sells NAD and SVS, Audio Art Cable sells Rega and Michell. The
pipeline gives every product the brand of the site it came from, so these
products would go into the catalogue under the wrong brand.

`extract` refuses a product when its name starts with the full name of another
brand in `var/brands.csv` ("NAD C 558" at Summit Hi-Fi). The reason is counted
as "a product of another brand". The other brand gets the product from its own
site. The words are compared without spaces ("TONE WINNER" is "ToneWinner"),
and a last word "Speakers" or "Loudspeakers" may be left off ("PSB Speakers"
sells as "PSB B600"). The test is in `OtherBrands` in `hifilog_import/scope.py`, and it does
not refuse:

- a name that starts with the brand of the site itself, or with a brand name
  that starts the same way ("Moon" and "Moon by Simaudio");
- a product of two brands, when the brand of the site comes right after the
  other brand ("Denon x Ojas DL-103O", "Klipsch/Ojas kO-R1");
- a brand name that is only generic words ("Ø Audio" reads as "audio");
- a brand name that is an ordinary word and that other brands use for their own
  ranges (`AMBIGUOUS_BRAND_NAMES`: Eclipse, Dual, Opera, Energy and others),
  also when it is read without spaces ("Pro-Ject" is "project", the name of a
  Furutech cable).

The first run refused 942 of 20469 candidates, most of them from shops such as
Audio Art Cable (199), Summit Hi-Fi (133) and GR Research (107).

## What the review still has to do

The importer produces the things that only a person can decide:

- **Which sub category is it?** A shop's own word for a category is carried as
  `source_category` ("Loudspeakers", "New in") and is never written as a hifilog
  sub category. Mapping it is a decision.

- **Is the product in scope?** Studio, PA, cinema and car audio are not, and a
  brand that makes both writes both on the same site.
- **Is it one product or a version of one?** Version words in a name are taken
  off (`CXA81 MKII Black UK/EU`), but whether the result is a new product or a
  variant of an existing one is a catalogue decision.
- **Is it the same product as one already in the catalogue?** Each candidate
  carries `match_keys`, and a shared key is a question, not an answer.

## Known limits

- A site that builds its pages in the browser gives an almost empty document.
  Such a site needs a browser to read it, which this tool does not have.
- A shop that shows a price per country gives the price of the country that the
  crawler appears to be in.
- Discontinued products are mostly not on a brand site at all. They are a
  separate source and a separate problem.
