-- Catalogue projection for contribute incomplete-product queues.
--
-- Same shape as product_items plus `completeness` / `specs_*`. Catalogue listings use the leaner
-- product_items view instead.
--
-- v02 drops sub_category_names (and its per-row correlated subquery), same reason as
-- product_items v21: it's display-only (nothing here filters or sorts on it), so it ran once for
-- every row matching the filter instead of just the ones displayed. ContributeProductItem now
-- batch-loads it for just the paginated page via ContributeProductItem.preload_sub_category_names.
--
-- v03 adds brand_abbreviation, mirroring product_items v22, so the contribute queues title
-- products the same way the catalogue does. See docs/catalog-model.md, "Brand".
--
-- v04 replaces the highlighted-specs LATERAL (which recomputed completeness / specs_applicable /
-- specs_filled from custom_attributes_sub_categories on every row) with plain reads of the
-- now-stored products.completeness / .specs_applicable / .specs_filled and
-- product_variants.completeness columns. RelatedProducts::Query sorts on completeness across up
-- to 8 UNION ALL branches per page load; recomputing it live per row was the dominant cost there.
-- Product keeps the three columns in sync on save and on sub_categories changes;
-- CustomAttribute does the same when `highlighted` or its own sub_categories change. See
-- Product#recalculate_completeness!.
--
-- v05 adds product_series_id and series_name, mirroring product_items v23, so
-- ContributeProductItem carries the same series columns as ProductItem (see
-- ContributeProductItemTest, which keeps the two column lists in step). The two columns are added
-- at the end, so the column order of v04 does not change.
--
-- The shared SELECT list is duplicated from product_items rather than composed
-- (`SELECT pi.*, ... FROM product_items pi`) on purpose: Postgres would then refuse to drop
-- product_items, so every later `update_view :product_items` would have to drop and recreate
-- this view too. ContributeProductItemTest asserts the two column lists stay in step.
--
-- Since v04 `completeness` only passes the stored columns through, so no weights live here. They
-- live in Ruby (Completeness::WEIGHTS and the Product / ProductVariant overrides) and in the
-- product_variants generated column. CompletenessScoreTest asserts they agree for every fixture row.
--
-- `specs_applicable` / `specs_filled` are exposed so ContributeProductItem.missing_specs can be
-- exact ("has specs to give and has not given them all") rather than a proxy for an empty JSONB.
SELECT
  uuid_generate_v5(uuid_ns_dns(), ('product-'::text || (products.id)::text)) AS id,
  products.name,
  products.description,
  products.discontinued,
  products.slug AS product_slug,
  products.release_day,
  products.release_month,
  products.release_year,
  products.price,
  products.price_currency,
  products.discontinued_year,
  products.discontinued_month,
  products.discontinued_day,
  products.diy_kit,
  products.model_no,
  products.custom_attributes,
  products.brand_id,
  brands.name AS brand_name,
  brands.abbreviation AS brand_abbreviation,
  'Product'::text AS item_type,
  products.created_at,
  products.updated_at,
  products.id AS product_id,
  NULL::bigint AS product_variant_id,
  NULL::text AS variant_name,
  NULL::text AS variant_description,
  NULL::text AS variant_slug,
  products.specs_applicable,
  products.specs_filled,
  products.completeness,
  products.product_series_id,
  product_series.name AS series_name
FROM products
LEFT JOIN brands ON brands.id = products.brand_id
LEFT JOIN product_series ON product_series.id = products.product_series_id

UNION ALL

SELECT
  uuid_generate_v5(uuid_ns_dns(), ('variant-'::text || (product_variants.id)::text)) AS id,
  products.name,
  products.description,
  product_variants.discontinued,
  products.slug AS product_slug,
  product_variants.release_day,
  product_variants.release_month,
  product_variants.release_year,
  product_variants.price,
  product_variants.price_currency,
  product_variants.discontinued_year,
  product_variants.discontinued_month,
  product_variants.discontinued_day,
  product_variants.diy_kit,
  product_variants.model_no,
  products.custom_attributes,
  products.brand_id,
  brands.name AS brand_name,
  brands.abbreviation AS brand_abbreviation,
  'ProductVariant'::text AS item_type,
  product_variants.created_at,
  product_variants.updated_at,
  product_variants.product_id,
  product_variants.id AS product_variant_id,
  product_variants.name AS variant_name,
  product_variants.description AS variant_description,
  product_variants.slug AS variant_slug,
  0::bigint AS specs_applicable,
  0::bigint AS specs_filled,
  product_variants.completeness,
  products.product_series_id,
  product_series.name AS series_name
FROM product_variants
JOIN products ON product_variants.product_id = products.id
LEFT JOIN brands ON brands.id = products.brand_id
LEFT JOIN product_series ON product_series.id = products.product_series_id
