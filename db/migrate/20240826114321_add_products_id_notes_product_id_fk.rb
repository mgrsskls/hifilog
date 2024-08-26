class AddProductsIdNotesProductIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :notes, :products, column: :product_id, primary_key: :id
  end
end
