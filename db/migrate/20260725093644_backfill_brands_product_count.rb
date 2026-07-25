class BackfillBrandsProductCount < ActiveRecord::Migration[8.1]
  def change
    execute <<~SQL
      UPDATE brands SET products_count = COALESCE(
        (SELECT COUNT(*) FROM products WHERE products.brand_id = brands.id), 0
      )
    SQL
    change_column_default :brands, :products_count, 0
    change_column_null :brands, :products_count, false
  end
end
