class AddProductPrefixIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :products, "left(lower(name),1)", name: "index_products_name_prefix"
  end
end
