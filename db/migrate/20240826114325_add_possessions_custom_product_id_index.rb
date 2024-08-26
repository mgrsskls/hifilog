class AddPossessionsCustomProductIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :possessions, :custom_product_id, name: :index_possessions_custom_product_id, unique: true
  end
end
