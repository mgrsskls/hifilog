# Bulk import from brand websites

This document describes how product data from brand websites gets into the catalog. It uses
Simplified Technical English (ASD-STE100).

## 1. Overview

The import has two parts:

1. **The importer** (`tools/brand_importer/`) reads brand websites and writes **candidate**
   products with a source for each field. It is a separate Python tool, not part of the
   application. It is slow, it uses the network, and it must run many times without a deploy. It
   never writes to the database. See `tools/brand_importer/README.md`.
2. **The staging area** in the application loads the candidates, and people review them. Only
   approved candidates become products.

Two rake tasks connect the application to the importer. The data goes in one direction only:

- `bin/rails import:brands` writes the brands that have a website, as CSV.
- `bin/rails import:schema` writes the sub categories and custom attributes as JSON. The importer
  has **no list of fields of its own**. It cannot import an attribute that ActiveAdmin does not
  define, and it refuses an option key that is not available. Run the task again after a change to
  the taxonomy or to an attribute.

The importer gives one candidate for each product page, with the source, the confidence and the
quoted words for each field.

## 2. Staging

The staging models are `ImportCandidate`, `ImportCategoryMapping` and `ImportBatch`.

| Model                   | Role                                                                             |
| ----------------------- | -------------------------------------------------------------------------------- |
| `ImportCandidate`       | A statement about a product, with provenance for each field. Waits for approval. |
| `ImportCategoryMapping` | A word of a shop → sub category. Decided one time.                               |
| `ImportBatch`           | One run of the importer. Traces a set of candidates.                             |

### 2.1 Candidates

`ImportCandidate` is **not a product**. It is what a page said, with a record of which part of the
page said it. It waits for a person. Nothing in staging gets into `products` automatically.

Three columns support the review. They are columns and not calculations, because thousands of rows
cannot be reviewed one form at a time:

- `provenance`: source, URL, quoted words and confidence **for each field**. A reviewer can see if
  the shop software stated a price or if the importer read it from a sentence.
- `score`: how complete the row is and how good its sources are. It does not measure truth. It
  shows where the next minute of review has the most value.
- `match_keys`: all spellings under which the product can already exist. The index answers the
  question "is this a duplicate?".

A candidate has an **array** of sub categories, not one. `Product` is
`has_and_belongs_to_many :sub_categories`, and the catalog needs this. For example, the Wisdom Audio
SUB1 is a subwoofer and an in-wall loudspeaker. A proposal with one sub category would be
incorrect for such a product, and no later step could see this. The array has a GIN index. Thus,
"which are classified" and "which are subwoofers" are both index reads.

### 2.2 Category mappings

`ImportCategoryMapping` changes a word of a shop into a sub category, one time.

Shops use the same word for many products. Thus, one decision covers many products.

- A mapping without a brand applies to the word everywhere.
- A mapping with a brand has priority over it.
- `out_of_scope` is a third answer, for a "Vinyl" or "Merch" category of a shop. Thus, a refusal is
  also decided one time, not one time for each run.

After the mappings, `import:map` corrects two things by the product name, because the word of a shop
cannot show them:

- A "pre-amplifier" with "phono" in its name moves to phono pre-amplifiers.
- An "interconnect" with a digital word in its name moves to digital cables. The digital words are
  AES/EBU, USB, streaming, Ethernet, HDMI, BNC, coaxial, S/PDIF, TOSLINK, optical, digital and I2S.

### 2.3 Verdicts of a second reading

**The verdict of a second reading decides the row.** Each candidate has its verdict in
`validation_verdict`.

- `import:load` rejects each pending row with the verdict `out_of_scope`. It writes the note of the
  reading as the `decision_note`.
- `import:map` writes only the rows that are `open_to_mapping`: rows with no verdict, or with the
  verdict `agreed` or `unsure`.
- The verdicts `corrected` and `classified` wrote the sub categories. The verdict `no_category`
  cleared them on purpose. A mapping does not overwrite them.

### 2.4 Corrections from the check

A check can also correct the product name. The title of a shop often has more than the name: the
brand, the product type, a pack size or a slogan ("F1-8 Standmount Speaker | Hi-Fi" is the F1-8).

- The check gives `corrected_name`. When the title has a finish or an edition, it also gives
  `corrected_variant`.
- The `validations` step writes them on the candidate. It keeps the title of the shop in
  `source_name`, because the key of the check comes from the title.
- The same step clears a model number that only repeats the product name. It ignores case, spaces
  and punctuation. Thus, the name is not stored two times.
- The same step marks a candidate as discontinued when the words of the shop say so:
  - a category such as "Discontinued models", "Archived Digital Cables" or "Legacy Products", or
  - a text at the end of the title such as "- Discontinued", "(DISCONTINUED)" or
    "– OUT OF PRODUCTION".

  `import:load` then loads the state. It does not depend on a mapping.

## 3. From a crawl to the catalog

```sh
rake import:load     # candidates.jsonl -> staging; never changes a decided row;
                     # rejects the rows that the check read as out of scope
rake import:map      # applies the mappings to the pending rows that are open to mapping
# review in ActiveAdmin: Import -> Import Candidates, and Unmapped categories
rake import:promote  # writes the approved candidates as products
```

### 3.1 Edit a candidate

**You can edit a candidate like a product** before it is approved or classified: name, variant,
model number, brand, release year, discontinued, DIY kit, price, description and sub categories.
`import:promote` writes what you saved.

- The importer never fills in the description. Only people write it, here.
- A saved edit sets `edited_at` and `edited_by`. After that, `import:load` and `import:map` do not
  change the row, the same as a decided row. Thus, the next run never removes a manual correction.

### 3.2 Candidate list

The candidate list is a grid of cards, not a table, because a candidate has too many fields for one
table row. ActiveAdmin 4 has only a table index. Thus, the grid is a component of this application,
`app/components/index_as_grid.rb`. It keeps the batch selection checkboxes of ActiveAdmin. It shows
sort links above the cards, because a grid has no column headers.

You can change the name in the card:

- The name is an input. The change is saved when the input loses focus or when you push Enter.
- The input sends one `PATCH` to `rename`. This marks the row as edited, the same as the form.
- The script is `app/assets/javascripts/admin_inline_edit.js`. It loads on each admin page and acts
  only on inputs with `data-inline-edit-url`. Thus, another index can use it for another field.

### 3.3 Publish one candidate

The "Publish" link on a card asks for a confirmation in the browser dialog. It approves the
candidate and runs the same `ImportPromotion` as `import:promote`. When the promotion fails, the
candidate keeps its previous status and the page shows the reason.

### 3.4 Approval writes nothing

`import:promote` is the only step that creates a `Product`. Thus, a failure has one place where it
is reported and tried again. A candidate that cannot become a product (no brand in the catalog, no
sub category, a price with no currency) stays approved, and the output names it.

## 4. Which environment does what

An import makes two different types of data. They belong in different places:

- **Products are catalog content.** They belong in production only. Do not review candidates in
  development and then move the products. That moves rows with their ids, slugs, versions and
  images, and it can damage the catalog.
- **Mappings are decisions.** They are small, they are the same in all environments, and they have
  value for a long time. Thus, they move as a committed file, the same as
  `custom_attributes:define` does for attribute definitions.

```sh
rake import:mappings:export   # decisions in this database -> db/import_category_mappings.yml
rake import:mappings:load     # the file -> decisions in this database
```

The file identifies brands and sub categories by **slug**, never by id. Ids are different in each
environment, slugs are not. When a slug is not found, the task reports it and skips it. A mapping on
the wrong sub category classifies hundreds of products incorrectly, and nothing shows it.

## 5. What moves, and how

An import makes three types of data. They go to three places:

|                                                                              | Location                                                         | How it gets to production                                     |
| ---------------------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------- |
| **Decisions**: category mappings, validation verdicts                        | `db/import_category_mappings.yml`, `db/import_validations.jsonl` | Committed. Deployed with the code.                            |
| **The candidate set**: all output of a crawl, already classified and checked | `tools/brand_importer/var/candidates.jsonl`                      | Copied to the server one time, loaded with `rake import:load` |
| **The crawl**: stored pages, extraction and classification caches            | `tools/brand_importer/var/`                                      | Never leaves the computer that did the crawl                  |

`candidates.jsonl` is a plain file. It does not need a commit. Copy it:

```sh
# on the computer that did the crawl
gzip -k tools/brand_importer/var/candidates.jsonl
scp tools/brand_importer/var/candidates.jsonl.gz you@server:/tmp/

# on the server
gunzip -c /tmp/candidates.jsonl.gz > tools/brand_importer/var/candidates.jsonl
rake import:load
rake import:map
```

The file has all the results of the local work: the sub categories that the classifier proposed,
the verdicts of a second reading (`validated_at`, `validated_by`, `validation_note`,
`validation_verdict`), the warnings, and the provenance of each field. `import:load` writes all of
this into staging. It never overwrites a row that a person already decided.

The decisions are committed, not copied. They are small, a person can read them as a diff, and they
have value for a long time: a mapping from today classifies the products of each future crawl, on
each computer. The crawl is large. It has no value after the candidates exist,
because a second crawl makes it again.

## 6. Production owns the review

Load, decide and promote the candidates in production. Use development only to practice the flow
with two or three brands. After the practice, `rake import:reset[yes]` empties the staging tables.
Thus, nobody can think that a practice run is the real review. The task does not run in production.
