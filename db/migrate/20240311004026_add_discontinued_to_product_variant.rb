class AddDiscontinuedToProductVariant < ActiveRecord::Migration[7.1]
  def change
    add_column :product_variants, :disabled, :boolean
    add_column :product_variants, :discontinued_day, :integer
    add_column :product_variants, :discontinued_month, :integer
    add_column :product_variants, :discontinued_year, :integer
  end
end
