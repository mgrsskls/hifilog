class ChangePriceColumnTypeToDecimal < ActiveRecord::Migration[7.1]
  def change
    change_column :products, :price, :decimal, precision: 12, scale: 4
  end
end
