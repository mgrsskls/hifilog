-- Products
SELECT
    uuid_generate_v5(uuid_ns_dns(), 'product-' || p.id::text) AS id,
    p.id AS item_id,
    'Product'::text AS item_type,
    p.name AS product_name,
    NULL::text AS product_variant_name,
    b.name AS brand_name,
    b.full_name AS brand_full_name,
    p.model_no,
    p.slug AS product_slug,
    NULL::text AS product_variant_slug,
    b.slug AS brand_slug
FROM products p
JOIN brands b
    ON b.id = p.brand_id

UNION ALL

-- Product Variants
SELECT
    uuid_generate_v5(uuid_ns_dns(), 'variant-' || pv.id::text) AS id,
    pv.id AS item_id,
    'ProductVariant'::text AS item_type,
    p.name AS product_name,
    pv.name AS product_variant_name,
    b.name AS brand_name,
    b.full_name AS brand_full_name,
    pv.model_no,
    p.slug AS product_slug,
    pv.slug AS product_variant_slug,
    b.slug AS brand_slug
FROM product_variants pv
JOIN products p
    ON pv.product_id = p.id
JOIN brands b
    ON b.id = p.brand_id

UNION ALL

-- Brands
SELECT
    uuid_generate_v5(uuid_ns_dns(), 'brand-' || b.id::text) AS id,
    b.id AS item_id,
    'Brand'::text AS item_type,
    NULL::text AS product_name,
    NULL::text AS product_variant_name,
    b.name AS brand_name,
    b.full_name AS brand_full_name,
    NULL::text AS model_no,
    NULL::text AS product_slug,
    NULL::text AS product_variant_slug,
    b.slug AS brand_slug
FROM brands b;
