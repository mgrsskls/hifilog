class AddSetupsIdSetupPossessionsSetupIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :setup_possessions, :setups, column: :setup_id, primary_key: :id
  end
end
