class AddFalseAsDefaultForPrevOwnedOnPossessions < ActiveRecord::Migration[7.1]
  def change
    change_column :possessions, :prev_owned, :boolean, default: false
  end
end
