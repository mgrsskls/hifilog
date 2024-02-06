class MakeUsernameRequired < ActiveRecord::Migration[7.1]
  def change
    change_column :users, :user_name, :string, null: false
    change_column :users, :email, :string, null: false
  end
end
