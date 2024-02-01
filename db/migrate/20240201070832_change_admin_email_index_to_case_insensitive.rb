class ChangeAdminEmailIndexToCaseInsensitive < ActiveRecord::Migration[7.1]
  def change
    remove_index :admin_users, name: 'index_admin_users_on_email'
    add_index :admin_users, 'lower(email)', name: 'index_admin_users_on_email', unique: true
  end
end
