class AddUserIdToNotes < ActiveRecord::Migration[7.1]
  def change
    add_column :notes, :user_id, :bigint, null: false
  end
end
