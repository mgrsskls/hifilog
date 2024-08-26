class AddProductOptionsProductVariantIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :product_options, :product_variant_id, name: :index_product_options_product_variant_id
  end
end
