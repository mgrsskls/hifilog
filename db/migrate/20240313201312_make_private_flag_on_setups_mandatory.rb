class MakePrivateFlagOnSetupsMandatory < ActiveRecord::Migration[7.1]
  def change
    change_column :setups, :private, :boolean, null: false
  end
end
