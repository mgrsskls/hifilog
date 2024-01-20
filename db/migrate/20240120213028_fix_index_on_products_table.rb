class FixIndexOnProductsTable < ActiveRecord::Migration[7.0]
  def change
    remove_index :products, name: "index_products_on_brand_id"
    add_index :products, [:name, :brand_id], unique: true
  end
end
