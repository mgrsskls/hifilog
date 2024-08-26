class AddPossessionsIdSetupPossessionsPossessionIdFk < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :setup_possessions, :possessions, column: :possession_id, primary_key: :id
  end
end
