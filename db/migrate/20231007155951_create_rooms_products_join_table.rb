class CreateRoomsProductsJoinTable < ActiveRecord::Migration[7.0]
  def change
    create_join_table :rooms, :products
  end
end
