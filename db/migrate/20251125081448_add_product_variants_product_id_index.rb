class AddProductVariantsProductIdIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :product_variants, :product_id, name: :index_product_variants_product_id
  end
end
