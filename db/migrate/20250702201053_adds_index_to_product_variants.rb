class AddsIndexToProductVariants < ActiveRecord::Migration[8.0]
  def change
    add_index :product_variants, [:name, :product_id, :model_no, :release_day, :release_month, :release_year], unique: true
  end
end
