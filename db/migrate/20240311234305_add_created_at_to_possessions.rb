class AddCreatedAtToPossessions < ActiveRecord::Migration[7.1]
  def change
    add_column :possessions, :created_at, :datetime
  end
end
