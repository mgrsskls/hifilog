class ChangeIndicesAfterChangeToCitext < ActiveRecord::Migration[7.1]
  def change
    remove_index :brands, name: 'index_brands_name_prefix'
    remove_index :brands, name: 'index_brands_on_name'
    remove_index :brands, name: 'index_brands_lower_slug_'
    remove_index :categories, name: 'index_categories_lower_name_'
    remove_index :categories, name: 'index_categories_lower_slug_'
    remove_index :products, name: 'index_products_name_prefix'

    add_index :brands, "left(name,1)", name: "index_brands_name_prefix"
    add_index :products, "left(name,1)", name: "index_products_name_prefix"
  end
end
