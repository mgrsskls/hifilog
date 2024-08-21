class AddProductOptionToPossession < ActiveRecord::Migration[7.1]
  def change
    add_column :possessions, :product_option_id, :bigint
  end
end
