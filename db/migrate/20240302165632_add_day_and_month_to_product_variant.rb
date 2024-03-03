class AddDayAndMonthToProductVariant < ActiveRecord::Migration[7.1]
  def change
    add_column :product_variants, :release_day, :integer
    add_column :product_variants, :release_month, :integer
    rename_column :product_variants, :year, :release_year
  end
end
