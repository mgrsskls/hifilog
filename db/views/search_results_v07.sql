-- v07 replaces brand_full_name with brand_abbreviation.
--
-- `full_name` was doing two jobs at once (longer marketing name / registered company
-- name), so nothing downstream could treat it consistently. It is now split into
-- brands.abbreviation and brands.legal_name -- see the Brand section of README.md.
--
-- abbreviation holds only short forms that are *not* already inside the brand name --
-- "B&O", not "Fezz". That narrowing is what makes it worth searching: a query for "fezz"
-- already reaches the prefix tier against "fezz audio" on brand_name alone, whereas "B&O"
-- normalises to "bo", which "bang olufsen" neither starts with nor contains. Without this
-- column that brand is unreachable.
--
-- legal_name is deliberately absent: pg_search concatenates every `against:` column into
-- one string before computing trigram similarity, so a long formulaic value nobody types
-- would dilute the score of every query.
--
-- Row cardinality is unchanged from v06: one row per product, variant and brand.

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
    b.abbreviation AS brand_abbreviation,
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
    b.abbreviation AS brand_abbreviation,
    NULL::text AS model_no,
    NULL::text AS product_slug,
    NULL::text AS product_variant_slug,
    b.slug AS brand_slug
FROM brands b;
