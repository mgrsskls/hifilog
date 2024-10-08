class ChangeUserEmailIndexToCaseInsensitive < ActiveRecord::Migration[7.1]
  def change
    remove_index :users, name: 'index_users_on_email'
    add_index :users, 'lower(email)', name: 'index_users_on_email', unique: true
  end
end
