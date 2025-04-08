class AddPricePurchaseAndPriceSaleToPossessions < ActiveRecord::Migration[8.0]
  def change
    add_column :possessions, :price_purchase, :decimal, precision: 12, scale: 4
    add_column :possessions, :price_purchase_currency, :string
    add_column :possessions, :price_sale, :decimal, precision: 12, scale: 4
    add_column :possessions, :price_sale_currency, :string
  end
end
