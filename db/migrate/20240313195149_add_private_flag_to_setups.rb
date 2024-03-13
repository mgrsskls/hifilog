class AddPrivateFlagToSetups < ActiveRecord::Migration[7.1]
  def change
    add_column :setups, :private, :boolean
  end
end
