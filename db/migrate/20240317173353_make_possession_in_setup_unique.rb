class MakePossessionInSetupUnique < ActiveRecord::Migration[7.1]
  def change
    add_index :setup_possessions, :possession_id, unique: true
  end
end
