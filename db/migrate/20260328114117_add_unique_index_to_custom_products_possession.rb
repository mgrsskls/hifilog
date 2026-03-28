class AddUniqueIndexToCustomProductsPossession < ActiveRecord::Migration[8.1]
  def change
    add_index :possessions, :custom_product_id, unique: true
  end
end
