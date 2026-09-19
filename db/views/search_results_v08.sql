-- v08 adds product series (docs/product-series.md):
--
-- * A fourth part with one row per series (item_type 'ProductSeries'). "klipsch heritage"
--   finds the series page through brand_name + series_name, "heritage" through series_name.
-- * series_name on product and variant rows. The series is not part of the product name, so
--   without this column "evolution omega lupi" would not find the product.
-- * series_slug, for the link of a series row.
--
-- Row cardinality: v07 plus one row per series.

-- Products
SELECT
    uuid_generate_v5(uuid_ns_dns(), 'product-' || p.id::text) AS id,
    p.id AS item_id,
    'Product'::text AS item_type,
    p.name AS product_name,
    NULL::text AS product_variant_name,
    b.name AS brand_name,
    b.abbreviation AS brand_abbreviation,
    p.model_no,
    p.slug AS product_slug,
    NULL::text AS product_variant_slug,
    b.slug AS brand_slug,
    ps.name AS series_name,
    ps.slug AS series_slug
FROM products p
JOIN brands b
    ON b.id = p.brand_id
LEFT JOIN product_series ps
    ON ps.id = p.product_series_id

UNION ALL

-- Product Variants
SELECT
    uuid_generate_v5(uuid_ns_dns(), 'variant-' || pv.id::text) AS id,
    pv.id AS item_id,
    'ProductVariant'::text AS item_type,
    p.name AS product_name,
    pv.name AS product_variant_name,
    b.name AS brand_name,
    b.abbreviation AS brand_abbreviation,
    pv.model_no,
    p.slug AS product_slug,
    pv.slug AS product_variant_slug,
    b.slug AS brand_slug,
    ps.name AS series_name,
    ps.slug AS series_slug
FROM product_variants pv
JOIN products p
    ON pv.product_id = p.id
JOIN brands b
    ON b.id = p.brand_id
LEFT JOIN product_series ps
    ON ps.id = p.product_series_id

UNION ALL

-- Brands
SELECT
    uuid_generate_v5(uuid_ns_dns(), 'brand-' || b.id::text) AS id,
    b.id AS item_id,
    'Brand'::text AS item_type,
    NULL::text AS product_name,
    NULL::text AS product_variant_name,
    b.name AS brand_name,
    b.abbreviation AS brand_abbreviation,
    NULL::text AS model_no,
    NULL::text AS product_slug,
    NULL::text AS product_variant_slug,
    b.slug AS brand_slug,
    NULL::citext AS series_name,
    NULL::citext AS series_slug
FROM brands b

UNION ALL

-- Product series
SELECT
    uuid_generate_v5(uuid_ns_dns(), 'series-' || ps.id::text) AS id,
    ps.id AS item_id,
    'ProductSeries'::text AS item_type,
    NULL::text AS product_name,
    NULL::text AS product_variant_name,
    b.name AS brand_name,
    b.abbreviation AS brand_abbreviation,
    NULL::text AS model_no,
    NULL::text AS product_slug,
    NULL::text AS product_variant_slug,
    b.slug AS brand_slug,
    ps.name AS series_name,
    ps.slug AS series_slug
FROM product_series ps
JOIN brands b
    ON b.id = ps.brand_id;
