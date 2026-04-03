class RemoveUnusedIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :products, name: "index_products_on_name"
    remove_index :products, name: "index_products_on_release_day"
    remove_index :products, name: "index_products_on_release_month"
    remove_index :products, name: "index_products_on_release_year"
    remove_index :product_variants, name: "index_product_variants_on_created_at"
  end
end
