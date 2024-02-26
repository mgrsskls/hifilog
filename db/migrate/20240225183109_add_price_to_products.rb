class AddPriceToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :price, :integer
    add_column :products, :price_currency, :string
  end
end
