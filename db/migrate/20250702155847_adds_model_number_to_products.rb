class AddsModelNumberToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :model_no, :string
    remove_index :products, name: "index_products_on_name_and_brand_id"
  end
end
