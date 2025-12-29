-- Products
SELECT
  'Product-' || products.id::text AS id,
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
  'Product' AS item_type,
  products.created_at,
  products.updated_at,
  products.id AS product_id,
  NULL::bigint AS product_variant_id,            -- Corrected alignment
  NULL::text AS variant_name,                    -- Ensure 'text' is compatible with 'citext' or cast it.
  NULL::text AS variant_description,             -- Changed to TEXT for better compatibility with potential full-text descriptions
  NULL::text AS variant_slug,
  ARRAY_AGG(DISTINCT sub_categories.name) AS sub_category_names
FROM products
LEFT JOIN brands ON brands.id = products.brand_id
LEFT JOIN products_sub_categories psc ON psc.product_id = products.id
LEFT JOIN sub_categories ON sub_categories.id = psc.sub_category_id
GROUP BY
  products.id, products.name, products.description, products.discontinued, products.slug,
  products.release_day, products.release_month, products.release_year,
  products.price, products.price_currency,
  products.discontinued_year, products.discontinued_month, products.discontinued_day,
  products.diy_kit, products.model_no, products.custom_attributes,
  products.brand_id, brands.name

UNION ALL

-- ProductVariants
SELECT
  'Variant-' || product_variants.id::text AS id,
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
  'ProductVariant' AS item_type,
  product_variants.created_at AS created_at,
  product_variants.updated_at AS updated_at,
  product_variants.product_id AS product_id,
  product_variants.id AS product_variant_id,     -- Corrected alignment
  product_variants.name AS variant_name,         -- Corrected alignment
  product_variants.description AS variant_description,
  product_variants.slug AS variant_slug,
  ARRAY_AGG(DISTINCT sub_categories.name) AS sub_category_names
FROM product_variants
JOIN products ON product_variants.product_id = products.id
LEFT JOIN brands ON brands.id = products.brand_id
LEFT JOIN products_sub_categories psc ON psc.product_id = products.id
LEFT JOIN sub_categories ON sub_categories.id = psc.sub_category_id
GROUP BY
  product_variants.id, products.name, products.description, product_variants.discontinued, products.slug,
  product_variants.release_day, product_variants.release_month, product_variants.release_year,
  product_variants.price, product_variants.price_currency,
  product_variants.discontinued_year, product_variants.discontinued_month, product_variants.discontinued_day,
  product_variants.diy_kit, product_variants.model_no, products.custom_attributes,
  products.brand_id, brands.name, product_variants.product_id, product_variants.name, product_variants.description,
  product_variants.slug
