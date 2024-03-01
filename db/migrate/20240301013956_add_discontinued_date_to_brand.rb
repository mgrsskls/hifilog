class AddDiscontinuedDateToBrand < ActiveRecord::Migration[7.1]
  def change
    add_column :brands, :discontinued_day, :integer
    add_column :brands, :discontinued_month, :integer
    add_column :brands, :discontinued_year, :integer
  end
end
