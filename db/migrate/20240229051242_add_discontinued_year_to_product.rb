class AddDiscontinuedYearToProduct < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :discontinued_year, :integer
  end
end
