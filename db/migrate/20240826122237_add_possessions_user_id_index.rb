class AddPossessionsUserIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :possessions, :user_id, name: :index_possessions_user_id
  end
end
