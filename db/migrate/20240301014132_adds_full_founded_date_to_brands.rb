class AddsFullFoundedDateToBrands < ActiveRecord::Migration[7.1]
  def change
    rename_column :brands, :year_founded, :founded_year
    add_column :brands, :founded_month, :integer
    add_column :brands, :founded_day, :integer
  end
end
