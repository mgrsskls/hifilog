class RenamePrevOwnedTableToPrevOwneds < ActiveRecord::Migration[7.1]
  def change
    rename_table :prev_owned, :prev_owneds
  end
end
