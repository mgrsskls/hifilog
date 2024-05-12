module BrandHelper
  def all_sub_categories(brand)
    SubCategory.find_by_sql(["
      SELECT * FROM (
        SELECT sub_categories.*
        FROM sub_categories
        INNER JOIN brands_sub_categories
        ON sub_categories.id = brands_sub_categories.sub_category_id
        WHERE brands_sub_categories.brand_id = ?
        UNION
        SELECT DISTINCT sub_categories.*
        FROM sub_categories
        INNER JOIN products_sub_categories
        ON products_sub_categories.sub_category_id = sub_categories.id
        INNER JOIN products ON products.id = products_sub_categories.product_id
        WHERE products.id IN (SELECT products.id FROM products WHERE products.brand_id = ?)
      ) AS sub_category ORDER BY sub_category.name
    ", brand.id, brand.id])
  end
end
