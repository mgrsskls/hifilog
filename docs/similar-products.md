# Similar Products and Similar Brands

This document describes the "Similar Products" block on product and variant pages and the "Similar
Brands" block on brand pages. It uses Simplified Technical English (ASD-STE100).

"Similar" and "related" are different questions. A **related** product connects to the entry (a
phono stage for a turntable, see [related-products.md](related-products.md)). A **similar** product
replaces it (another turntable).

## 1. Similar Products

### 1.1 Block and full list

The **"Similar Products"** block on product and variant pages lists products that have the same
role as the entry: other products that a user can compare with it.

- The block is above "Related Products" and uses the same list layout.
- It shows `RelatedProducts::Query::PER_GROUP` items, the same number as one group of "Related
  Products".
- When no candidate has the minimum score, the application does not show the block.

When there are more candidates than the block shows, a **"View all"** link opens the full list at
`/products/:product_id/similar` (`ProductsController#similar`):

- The page shows all candidates with the minimum score, in the same order, with pagination
  (`SimilarProducts::PER_PAGE`, the Kaminari default).
- It uses the layout of `brands#products` (`shared/index_page`). The sidebar on the left shows the
  product (name, category, dates, price and characteristics). The content on the right shows the
  list.
- The data list is the partial `products/_data`. The product page also uses it.
- On viewports narrower than 48rem, the page shows only the headline. The product data
  (`.IndexPage-details`) is hidden.
- The page is `noindex, follow`, because it is a list of other catalog pages.

A variant has its own page at `/products/:product_id/v/:id/similar`
(`ProductVariantsController#similar`). The list is the same as the list of the parent product,
because the ranking uses the attributes of the product. The sidebar shows the variant: its name,
dates and price, with the categories and characteristics of the product. The two pages render
`shared/_similar_products_page`.

### 1.2 Candidates

- A candidate must have at least one sub category in common with the product.
- The product itself is not a candidate.
- Candidates are base products only, not variants.
- There are no other exclusions. The block does not remove products of the same brand, the same
  product series or the "Related Products" block.

A variant page shows the list of its parent product. Variants have no custom attributes of their
own, so a list for each variant would be almost the same list.

### 1.3 Ranking

Candidates with exactly the same sub categories always come first. In each of these two groups, the
**score** sets the order. The score is the sum of these parts:

| Part                       | Points                                                                                                 |
| -------------------------- | ------------------------------------------------------------------------------------------------------ |
| **Sub category overlap**   | `100 * shared / all` (Jaccard index) of the sub categories of the two products                         |
| **Categorical attributes** | `weight * shared / all` of the values of the two products, for option, options and boolean attributes  |
| **Numeric classes**        | `weight` when the two values are in the same class, for example output power < 25 W, 25–100 W, > 100 W |
| **Price band**             | 2 for the same band, 1 for the next band. A band is approximately x3 wide. Same currency only.         |

When the scores are equal, these values set the order:

1. The same discontinued status as the product.
2. The smallest difference in release year. A missing year comes last.
3. The product id, so that the order is always the same.

A missing value on one side gives 0 points, not a penalty. Thus, a candidate with more data can get
more points. The brand does not change the score. The series does not change the score.

**`SimilarProducts::Weights`** holds all tuning values as Ruby constants:

- The weight of each attribute label: 3 = defines what the product is, 2 = important, 1 = small
  detail. A label that is not in the list is ignored.
- The numeric classes, the width of a price band and the minimum score.

Dimensions, weight and sensitivity are not used, because they are too specific to one product. A
test makes sure that each label in the weights exists.

### 1.4 Implementation

- **`SimilarProducts.for`** gives the block. `ProductCatalogShowService` calls it.
- **`SimilarProducts.page`** gives one page of the full list as a Kaminari array.
- **`SimilarProducts::Query`** calculates the score of all candidates in one SQL statement. It gives
  only the ids of the requested rows (`LIMIT` and `OFFSET`) and the number of all candidates with the
  minimum score. The block uses this number to decide if it shows "View all".

Performance rules of the query:

- The index on `products_sub_categories.sub_category_id` finds the candidates. Thus, the work
  depends on the size of the sub categories of the product, not on the size of the catalog.
- The values of the product are constants in the SQL. The query has one term for each attribute
  that the product has.
- Nested subqueries with `OFFSET 0` make sure that PostgreSQL calculates each attribute array one
  time for each row.
- Ruby calculates the limits of the price bands. `log()` on a numeric column is slow.
- The uuid of a `ProductItem` is calculated only for the rows in the result.
- The statement always gives one row, also for a page after the last page. Thus, the total is
  always known.

For reference: 5,000 candidates take approximately 60 ms, 30,000 candidates approximately 190 ms. A
later page costs the same as the first page, because the query scores all candidates each time.

### 1.5 Cache

The ranked ids and the total are **cached** for 24 hours, one entry for each page. The key contains:

- the product (`cache_key_with_version`)
- its sub category ids
- the limit and the offset
- `SimilarProducts::CACHE_VERSION`

The records load on each request. Thus, a changed name or image of a candidate shows immediately.
A new or changed candidate gets into an existing list when the cache entry expires. **When you
change the scoring, increase `CACHE_VERSION`.**

## 2. Similar Brands

### 2.1 Block and full list

The **"Similar Brands"** block on the brand page lists brands that make the same type of products.
It works like Similar Products:

- The same list layout and the same number of items (`SimilarBrands::LIMIT`).
- A **"View all"** link when there are more candidates.
- A full, paginated list at `/brands/:brand_id/similar` (`BrandsController#similar`). The sidebar
  shows the brand (the partial `brands/_data`, which the brand page also uses). The page is
  `noindex, follow`, and shows only the headline on viewports narrower than 48rem.

A brand has little data of its own. Thus, most of the signal comes from its **products**. A
candidate must have at least one product in a sub category of the brand. Its profile uses only
these products. For example, a turntable brand is compared on turntables, also when the candidate
makes amplifiers too.

### 2.2 Ranking

The score is the sum of these parts. The weights are in **`SimilarBrands::Weights`**.

| Part                     | Points                                                                                                                                                              |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Sub category profile** | `100 * Σ min(share of the brand, share of the candidate)` over the sub categories of the brand. A share is the part of all products of a brand in one sub category. |
| **Active period**        | `20 * shared years / all years`. A brand is active from its founded year to its discontinued year, or to this year. An unknown start or end gives 0.                |
| **Country**              | 15 for the same country                                                                                                                                             |
| **Price level**          | 10 for the same band of the median product price, 5 for the next band. Same bands as for products, same currency only.                                              |
| **Attributes**           | For each attribute in `SimilarProducts::Weights::ATTRIBUTES`: `weight * the part of the products of the candidate with the most frequent value of the brand`        |

When the scores are equal, the same discontinued status comes first, then the brand with more
products, then the brand id. The application does not show candidates with less than `MIN_SCORE`
(10).

The share makes a specialist rank above a generalist. For example, a brand with 1 turntable in 16
products gets only 6.25 points for a turntable brand.

### 2.3 Implementation

**`SimilarBrands.for`** gives the block and **`SimilarBrands.page`** gives one page of the full list.
**`SimilarBrands::Query`** works in two steps:

1. Ruby reads the profile of the brand from its own products: the share in each sub category, the
   most frequent value of each weighted attribute, and the median price in its most frequent
   currency.
2. One SQL statement makes the same profile for all candidate brands, calculates the scores, and
   gives only the ids of the requested rows and the number of all candidates.

The index on `products_sub_categories.sub_category_id` finds the products. The work depends on the
number of products in the sub categories of the brand. For reference, with 200,000 products: a
brand in one sub category takes approximately 70 ms, a brand in all sub categories approximately
700 ms (it reads the full catalog).

The query counts all products of a candidate. It does not use `brands.products_count`, because
that column also counts variants.

### 2.4 Cache

The ranked ids and the total are **cached** for 24 hours, one entry for each page. The key contains
the brand (`cache_key_with_version`), the limit, the offset and `SimilarBrands::CACHE_VERSION`.

A product change touches its brand (`belongs_to :brand, touch: true`). Thus, a change to the
products of the brand makes a new key. A change of a candidate gets into existing lists when the
entry expires.

## 3. Shared SQL

**`SimilaritySql`** (`app/services/concerns`) holds the SQL parts that the two queries use:
attribute values as JSON arrays, price bands and quoting.
