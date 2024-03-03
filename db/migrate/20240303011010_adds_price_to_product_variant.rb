class AddsPriceToProductVariant < ActiveRecord::Migration[7.1]
  def change
    add_column :product_variants, :price, :decimal, precision: 12, scale: 4
    add_column :product_variants, :price_currency, :string
  end
end
