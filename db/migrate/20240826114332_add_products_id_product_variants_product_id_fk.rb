class AddProductsIdProductVariantsProductIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :product_variants, :products, column: :product_id, primary_key: :id
  end
end
