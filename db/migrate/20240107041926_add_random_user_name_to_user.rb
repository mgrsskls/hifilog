class AddRandomUserNameToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :random_username, :string
  end
end
