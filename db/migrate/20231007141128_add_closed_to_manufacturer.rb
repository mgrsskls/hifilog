class AddClosedToManufacturer < ActiveRecord::Migration[7.0]
  def change
    add_column :manufacturers, :closed, :boolean
  end
end
