class RenameProductsUsersToPossessions < ActiveRecord::Migration[7.1]
  def change
    rename_table :products_users, :possessions
    rename_column :possessions, :variant_id, :product_variant_id
  end
end
