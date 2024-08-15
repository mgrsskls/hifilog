class AddUserIdToCustomProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :custom_products, :user_id, :bigint, null: false
    drop_join_table :custom_products, :users
  end
end
