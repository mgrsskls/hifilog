class ChangeSetupPossessionsPossessionIdNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :setup_possessions, :possession_id, false
  end
end
