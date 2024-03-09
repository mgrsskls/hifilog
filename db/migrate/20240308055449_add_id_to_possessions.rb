class AddIdToPossessions < ActiveRecord::Migration[7.1]
  def change
    add_column :possessions, :id, :primary_key
  end
end
