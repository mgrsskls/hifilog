class AddProductVariantToSetups < ActiveRecord::Migration[7.1]
  def change
    rename_table :products_setups, :setup_products
    add_column :setup_products, :product_variant_id, :bigint
  end
end
