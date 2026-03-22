class RemoveRedundantEmailIndexOnUsers < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, :index_users_email, if_exists: true
  end
end
