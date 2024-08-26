class AddCustomProductsIdPossessionsCustomProductIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :possessions, :custom_products, column: :custom_product_id, primary_key: :id
  end
end
