-- Products
SELECT
  products.id,
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
  products.id AS product_id,
  NULL AS variant_name,
  NULL AS variant_description,
  NULL AS variant_slug,
  array_agg(DISTINCT sub_categories.name) AS sub_category_names
FROM products
LEFT JOIN brands ON brands.id = products.brand_id
LEFT JOIN products_sub_categories psc ON psc.product_id = products.id
LEFT JOIN sub_categories ON sub_categories.id = psc.sub_category_id
GROUP BY
  products.id, products.name, products.description, products.discontinued,
  products.slug, products.release_day, products.release_month, products.release_year,
  products.price, products.price_currency, products.discontinued_year,
  products.discontinued_month, products.discontinued_day, products.diy_kit,
  products.model_no, products.custom_attributes, products.brand_id, brands.name

UNION ALL

SELECT
  product_variants.id,
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
  product_variants.product_id,
  product_variants.name AS variant_name,
  product_variants.description AS variant_description,
  product_variants.slug AS variant_slug,
  array_agg(DISTINCT sub_categories.name) AS sub_category_names
FROM product_variants
JOIN products ON product_variants.product_id = products.id
LEFT JOIN brands ON brands.id = products.brand_id
LEFT JOIN products_sub_categories psc ON psc.product_id = products.id
LEFT JOIN sub_categories ON sub_categories.id = psc.sub_category_id
GROUP BY
  product_variants.id, products.name, products.description, product_variants.discontinued,
  products.slug, product_variants.release_day, product_variants.release_month,
  product_variants.release_year, product_variants.price, product_variants.price_currency,
  product_variants.discontinued_year, product_variants.discontinued_month,
  product_variants.discontinued_day, product_variants.diy_kit, product_variants.model_no,
  products.custom_attributes, products.brand_id, brands.name,
  product_variants.product_id, product_variants.name, product_variants.description,
  product_variants.slug;
