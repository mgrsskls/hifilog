-- Products
SELECT
    p.id AS item_id,
    'Product'::text AS item_type,
    p.name AS product_name,
    NULL::text AS product_variant_name,
    b.name AS brand_name,
    p.model_no
FROM products p
JOIN brands b
    ON b.id = p.brand_id

UNION ALL

-- Product Variants
SELECT
    pv.id AS item_id,
    'ProductVariant'::text AS item_type,
    p.name AS product_name,
    pv.name AS product_variant_name,
    b.name AS brand_name,
    pv.model_no
FROM product_variants pv
JOIN products p
    ON pv.product_id = p.id
JOIN brands b
    ON b.id = p.brand_id

UNION ALL

-- Brands
SELECT
    b.id AS item_id,
    'Brand'::text AS item_type,
    NULL::text AS product_name,
    NULL::text AS product_variant_name,
    b.name AS brand_name,
    NULL::text AS model_no
FROM brands b;
