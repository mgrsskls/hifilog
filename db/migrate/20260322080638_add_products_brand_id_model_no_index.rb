class AddProductsBrandIdModelNoIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :products, %w[brand_id model_no], name: :index_products_brand_id_model_no, unique: true
  end
end
