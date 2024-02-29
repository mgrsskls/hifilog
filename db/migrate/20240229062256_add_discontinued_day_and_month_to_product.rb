class AddDiscontinuedDayAndMonthToProduct < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :discontinued_month, :integer
    add_column :products, :discontinued_day, :integer
  end
end
