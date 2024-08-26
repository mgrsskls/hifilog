class AddAdminUsersEmailIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :admin_users, :email, name: :index_admin_users_email, unique: true
  end
end
