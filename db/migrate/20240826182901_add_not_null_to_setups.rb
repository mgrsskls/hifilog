class AddNotNullToSetups < ActiveRecord::Migration[7.1]
  def change
    change_column :setups, :user_id, :bigint, null: false
  end
end
