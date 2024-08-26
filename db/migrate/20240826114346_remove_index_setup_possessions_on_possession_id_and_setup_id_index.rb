class RemoveIndexSetupPossessionsOnPossessionIdAndSetupIdIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index nil, name: 'index_setup_possessions_on_possession_id_and_setup_id'
  end
end
