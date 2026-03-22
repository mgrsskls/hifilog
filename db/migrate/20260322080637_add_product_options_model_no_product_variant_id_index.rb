class AddProductOptionsModelNoProductVariantIdIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :product_options, %w[model_no product_variant_id], name: :index_product_options_model_no_product_variant_id, unique: true
  end
end
