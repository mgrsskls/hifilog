class AddMovedToPreviousAtToPossessions < ActiveRecord::Migration[8.1]
  def change
    add_column :possessions, :moved_to_previous_at, :datetime
  end
end
