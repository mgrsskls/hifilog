class ChangeSetupsNameNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :setups, :name, false
  end
end
