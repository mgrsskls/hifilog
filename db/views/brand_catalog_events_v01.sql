-- Catalog entries as feed events, flattened the way product_items flattens catalog rows.
-- Nothing is stored: a deleted product leaves the feed and a re-branded product moves with its
-- brand, both without a write path or a cleanup task.
--
-- product_items is deliberately not reused here. It carries the completeness lateral joins,
-- and the feed needs five columns and a date.
SELECT
  uuid_generate_v5(uuid_ns_dns(), ('product-'::text || (products.id)::text)) AS id,
  'product'::text AS source,
  products.id AS product_id,
  NULL::bigint AS product_variant_id,
  products.brand_id,
  products.created_at AS occurred_at
FROM products
UNION ALL
SELECT
  uuid_generate_v5(uuid_ns_dns(), ('variant-'::text || (product_variants.id)::text)) AS id,
  'product_variant'::text AS source,
  product_variants.product_id,
  product_variants.id AS product_variant_id,
  products.brand_id,
  product_variants.created_at AS occurred_at
FROM product_variants
JOIN products ON products.id = product_variants.product_id;
