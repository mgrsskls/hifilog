class AddUserIdToRoom < ActiveRecord::Migration[7.0]
  def change
    add_column :rooms, :user_id, :integer
  end
end
