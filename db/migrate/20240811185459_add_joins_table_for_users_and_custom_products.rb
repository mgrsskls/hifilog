class AddJoinsTableForUsersAndCustomProducts < ActiveRecord::Migration[7.1]
  def change
    create_join_table :users, :custom_products
  end
end
