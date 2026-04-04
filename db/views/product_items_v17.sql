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
  ) AS sub_category_names
FROM products
LEFT JOIN brands ON brands.id = products.brand_id

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
  ) AS sub_category_names
FROM product_variants
JOIN products ON product_variants.product_id = products.id
LEFT JOIN brands ON brands.id = products.brand_id