class AddProductsCountToBrands < ActiveRecord::Migration[7.1]
  def change
    add_column :brands, :products_count, :integer
  end
end
