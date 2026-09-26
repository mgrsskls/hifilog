# Completeness and contribute queues

This document describes the completeness score and the contribute queues. It uses Simplified
Technical English (ASD-STE100).

## 1. Completeness

Most brands, products and product variants have only a name (and a brand). Thus, _incomplete_ is the normal state, not an
error.

The **`Completeness`** concern is included in `Brand`, `Product` and `ProductVariant`. It shows how
complete an entry is in two ways:

- **Named gaps**, for the prompts on the entry pages.
- A **score from 0 to 100**, for the order of the queues.

Each model sets the weight of its own fields. The weight is approximately in proportion to the
number of places that use the field.

### 1.1 Rules

- **A field that does not apply does not decrease the score.** It leaves the denominator. It does
  not count as missing. Thus, no entry is always below 100% because of a field that nobody can fill
  in.
- **Highlighted custom attributes** are the "key specs" of the application. The score counts them as
  one group.
- Variants use the attributes of the parent and cannot edit them. Thus, custom attributes are not part
  of the score of a variant.

### 1.2 Two calculations

**The application calculates the score of brands and product variants two times:**

- In Ruby, for the display.
- In SQL, as a generated column, so that the database can sort and filter on the score.

A test makes sure that the two calculations give the same result.

Products calculate their score only in Ruby. They store the result in columns, so that the database
can sort and filter on it (see [1.3](#13-when-the-score-of-products-changes)).

### 1.3 When the score of products changes

Products store their score in columns (`completeness`, `specs_applicable`, `specs_filled`).

- A product save calculates its own score again, synchronously.
- A change to a highlighted custom attribute can change all products in a sub category. This
  calculation runs in the background (`SubCategoryCompletenessJob`, see
  [background-jobs.md](background-jobs.md)).
- `rake completeness:backfill_products` calculates all scores synchronously.

## 2. Contribute queues

**`ContributeController`** is a task board for contributors. Each queue lists the entries that do
not have one specific, named value. The pages are read-only and `noindex`. Each link opens the
existing brand or product edit form.

There are queues for:

- Brands with no products.
- Brands without a specific field.
- Products without a specific field.

Each queue can be limited to a `Category`. Each queue is ordered by **descending completeness**. The
entries that are almost complete come first. Thus, a contributor gets a small task that they can
complete, not an empty form.

The queues read the `ContributeProductItem` view (see
[catalog-listing-and-search.md](catalog-listing-and-search.md#3-contribute-product-items-contributeproductitem)).

## 3. Contribution guidelines

The rules for contributors are on one page, **`/contribute/guidelines`**
(`ContributeController#guidelines`). It is the only indexed page of the controller, and it does no
database queries. Each chapter is a partial in `app/views/contribute/guidelines/`. The entry forms
(brand, product, variant, series) show a summary from the same folder. They link to single sections
with **`GuidelinesHelper#guideline_link`**. The section ids come from
`GuidelinesHelper::GUIDELINE_SECTIONS` and do not change when a section gets a new number. For the files and the rules to change the guidelines,
see [contribution-guidelines.md](contribution-guidelines.md).
