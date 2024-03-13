class SetDefaultValueForPrivateInSetups < ActiveRecord::Migration[7.1]
  def change
    change_column_null :setups, :private, false, false
  end
end
