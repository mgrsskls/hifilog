class DropPrevOwnedsTable < ActiveRecord::Migration[7.1]
  def change
    drop_table :prev_owneds
  end
end
