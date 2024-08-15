class AddPrevOwnedToPossessions < ActiveRecord::Migration[7.1]
  def change
    add_column :possessions, :prev_owned, :boolean
  end
end
