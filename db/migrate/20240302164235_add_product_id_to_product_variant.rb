class AddProductIdToProductVariant < ActiveRecord::Migration[7.1]
  def change
    add_column :product_variants, :product_id, :bigint
  end
end
