class AddUsersIdSetupsUserIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :setups, :users, column: :user_id, primary_key: :id
  end
end
