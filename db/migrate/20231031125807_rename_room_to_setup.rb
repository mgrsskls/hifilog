class RenameRoomToSetup < ActiveRecord::Migration[7.0]
  def change
    rename_table :rooms, :setups
    rename_table :products_rooms, :products_setups
    rename_column :products_setups, :room_id, :setup_id
  end
end
