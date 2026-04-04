class AddIndexToPossessionsUserIdAndPrevOwned < ActiveRecord::Migration[8.1]
  def change
    add_index :possessions, [:user_id, :prev_owned]
  end
end
