class AddMissingIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :products, :discontinued
    add_index :products, [:release_year, :release_month, :release_day]
    add_index :products, :diy_kit
    add_index :product_variants, :discontinued
    add_index :product_variants, [:release_year, :release_month, :release_day]
    add_index :product_variants, :diy_kit
    add_index :brands, :discontinued
    add_index :brands, [:founded_year, :founded_month, :founded_day]
  end
end
