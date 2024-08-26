class AddUsersIdCustomProductsUserIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :custom_products, :users, column: :user_id, primary_key: :id
  end
end
