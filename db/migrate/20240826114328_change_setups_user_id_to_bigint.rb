class ChangeSetupsUserIdToBigint < ActiveRecord::Migration[7.1]
  def change
    change_column :setups, :user_id, :bigint
  end
end
