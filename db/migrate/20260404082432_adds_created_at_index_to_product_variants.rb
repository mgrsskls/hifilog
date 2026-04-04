class AddsCreatedAtIndexToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_index :product_variants, :created_at
  end
end
