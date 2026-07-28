class BackfillBrandsProductCountWithVariants < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE brands SET products_count = (
        SELECT COUNT(*) FROM products WHERE products.brand_id = brands.id
      ) + (
        SELECT COUNT(*) FROM product_variants
        JOIN products ON products.id = product_variants.product_id
        WHERE products.brand_id = brands.id
      )
    SQL
  end

  def down
    execute <<~SQL
      UPDATE brands SET products_count = (
        SELECT COUNT(*) FROM products WHERE products.brand_id = brands.id
      )
    SQL
  end
end
