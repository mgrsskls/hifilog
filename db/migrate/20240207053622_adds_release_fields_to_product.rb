class AddsReleaseFieldsToProduct < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :release_day, :integer
    add_column :products, :release_month, :integer
    add_column :products, :release_year, :integer
  end
end
