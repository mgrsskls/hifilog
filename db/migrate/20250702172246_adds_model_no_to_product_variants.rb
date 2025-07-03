class AddsModelNoToProductVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :product_variants, :model_no, :string
    add_index :product_variants, :model_no, unique: true
  end
end
