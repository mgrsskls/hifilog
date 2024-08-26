class AddProductOptionsProductIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :product_options, :product_id, name: :index_product_options_product_id
  end
end
