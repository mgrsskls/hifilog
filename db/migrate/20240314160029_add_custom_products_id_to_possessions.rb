class AddCustomProductsIdToPossessions < ActiveRecord::Migration[7.1]
  def change
    add_column :possessions, :custom_product_id, :bigint
    change_column_null :possessions, :product_id, true
    remove_column :custom_products, :user_id
  end
end
