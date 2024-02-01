class ChangeUserNameIndexToCaseInsensitive < ActiveRecord::Migration[7.1]
  def change
    remove_index :users, name: 'index_users_on_user_name'
    add_index :users, 'lower(user_name)', name: 'index_users_on_user_name', unique: true
  end
end
