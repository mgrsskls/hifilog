-- v18 adds `completeness`: a 0-100 score of how much of an entry has been filled in.
--
-- The weights must stay in step with Completeness::WEIGHTS and the per-model overrides in Ruby
-- (Product, ProductVariant). CompletenessScoreTest asserts the two agree for every fixture row.
--
-- Products score out of 8 (description 3, highlighted specs 3, release year 2), or out of 5 when
-- none of their sub categories define a highlighted attribute — a spec that cannot exist is
-- dropped from the denominator rather than counted as missing. The specs term pays 2 points for
-- the fraction filled plus a 1 point bonus only once the set is closed, so finishing an entry
-- beats starting one.
--
-- Variants score out of 5 on their own description and release year. Specs are excluded because
-- a variant cannot edit the parent product's custom attributes, so their spec counts are 0.
--
-- `specs_applicable` / `specs_filled` are exposed so ProductItem.missing_specs can be exact
-- ("has specs to give and has not given them all") rather than a proxy for an empty JSONB.
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
  'Product'::text AS item_type,
  products.created_at,
  products.updated_at,
  products.id AS product_id,
  NULL::bigint AS product_variant_id,
  NULL::text AS variant_name,
  NULL::text AS variant_description,
  NULL::text AS variant_slug,
  (
    SELECT array_agg(sub_categories.name)
    FROM products_sub_categories psc
    JOIN sub_categories ON sub_categories.id = psc.sub_category_id
    WHERE psc.product_id = products.id
  ) AS sub_category_names,
  spec.applicable AS specs_applicable,
  spec.filled AS specs_filled,
  (ROUND(
    100.0 * (
        CASE WHEN NULLIF(BTRIM(products.description), '') IS NOT NULL THEN 3 ELSE 0 END
      + CASE WHEN products.release_year IS NOT NULL THEN 2 ELSE 0 END
      + CASE
          WHEN spec.applicable = 0 THEN 0
          ELSE 2.0 * spec.filled / spec.applicable
               + CASE WHEN spec.filled = spec.applicable THEN 1 ELSE 0 END
        END
    ) / CASE WHEN spec.applicable = 0 THEN 5 ELSE 8 END
  ))::integer AS completeness
FROM products
LEFT JOIN brands ON brands.id = products.brand_id
LEFT JOIN LATERAL (
  SELECT
    count(DISTINCT ca.id) AS applicable,
    count(DISTINCT ca.id) FILTER (
      WHERE products.custom_attributes ? ca.label
        AND jsonb_typeof(products.custom_attributes -> ca.label) <> 'null'
        AND products.custom_attributes ->> ca.label <> ''
    ) AS filled
  FROM custom_attributes ca
  JOIN custom_attributes_sub_categories casc ON casc.custom_attribute_id = ca.id
  JOIN products_sub_categories psc ON psc.sub_category_id = casc.sub_category_id
  WHERE ca.highlighted
    AND psc.product_id = products.id
) spec ON TRUE

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
  'ProductVariant'::text AS item_type,
  product_variants.created_at,
  product_variants.updated_at,
  product_variants.product_id,
  product_variants.id AS product_variant_id,
  product_variants.name AS variant_name,
  product_variants.description AS variant_description,
  product_variants.slug AS variant_slug,
  (
    SELECT array_agg(sub_categories.name)
    FROM products_sub_categories psc
    JOIN sub_categories ON sub_categories.id = psc.sub_category_id
    WHERE psc.product_id = products.id
  ) AS sub_category_names,
  0::bigint AS specs_applicable,
  0::bigint AS specs_filled,
  (ROUND(
    100.0 * (
        CASE WHEN NULLIF(BTRIM(product_variants.description), '') IS NOT NULL THEN 3 ELSE 0 END
      + CASE WHEN product_variants.release_year IS NOT NULL THEN 2 ELSE 0 END
    ) / 5
  ))::integer AS completeness
FROM product_variants
JOIN products ON product_variants.product_id = products.id
LEFT JOIN brands ON brands.id = products.brand_id
