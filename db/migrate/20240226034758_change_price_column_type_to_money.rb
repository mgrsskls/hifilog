class ChangePriceColumnTypeToMoney < ActiveRecord::Migration[7.1]
  def change
    change_column :products, :price, :money
  end
end
