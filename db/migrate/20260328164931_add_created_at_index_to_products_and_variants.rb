class AddCreatedAtIndexToProductsAndVariants < ActiveRecord::Migration[8.1]
  def change
    add_index :products, :created_at
    add_index :product_variants, :created_at
  end
end
