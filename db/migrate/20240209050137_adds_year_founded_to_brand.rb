class AddsYearFoundedToBrand < ActiveRecord::Migration[7.1]
  def change
    add_column :brands, :year_founded, :integer
  end
end
