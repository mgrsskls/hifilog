class AddUsersIdNotesUserIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :notes, :users, column: :user_id, primary_key: :id
  end
end
