class AddProductsIdPossessionsProductIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :possessions, :products, column: :product_id, primary_key: :id
  end
end
