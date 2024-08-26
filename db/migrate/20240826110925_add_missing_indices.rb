class AddMissingIndices < ActiveRecord::Migration[7.1]
  def change
    add_index :possessions, [:user_id, :custom_product_id], unique: true
  end
end
