class AddUniqueIndexToUserAndNameOnCustomProducts < ActiveRecord::Migration[7.1]
  def change
    add_index :custom_products, [:user_id, :name], unique: true
  end
end
