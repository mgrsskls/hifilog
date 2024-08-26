class ChangePossessionsPrevOwnedNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :possessions, :prev_owned, false
  end
end
