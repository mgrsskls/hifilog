class AddProductOptionsIdPossessionsProductOptionIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :possessions, :product_options, column: :product_option_id, primary_key: :id
  end
end
