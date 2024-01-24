class RemoveRandomUserName < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :random_username
  end
end
