class AddsModelNoToProductOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :product_options, :model_no, :string
    add_index :product_options, [:model_no, :product_id], unique: true
    add_index :product_options, [:model_no, :product_variant_id], unique: true
  end
end
