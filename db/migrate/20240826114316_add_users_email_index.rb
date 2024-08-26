class AddUsersEmailIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :users, :email, name: :index_users_email, unique: true
  end
end
