class AddIndexToProductOptions < ActiveRecord::Migration[7.1]
  def change
    add_index :product_options, [:option, :product_id], unique: true
    add_index :product_options, [:option, :product_variant_id], unique: true
  end
end
