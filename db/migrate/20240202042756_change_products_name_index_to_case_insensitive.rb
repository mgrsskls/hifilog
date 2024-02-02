class ChangeProductsNameIndexToCaseInsensitive < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'citext'
    remove_index :products, name: 'index_products_on_name_and_brand_id'
    add_index :products, [:name, :brand_id], name: 'index_products_on_name_and_brand_id', unique: true
    change_column :products, :name, :citext
  end
end
