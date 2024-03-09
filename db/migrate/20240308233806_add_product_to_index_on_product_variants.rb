class AddProductToIndexOnProductVariants < ActiveRecord::Migration[7.1]
  def change
    change_column :product_variants, :name, :string, null: false
    add_index :product_variants, [:product_id, :name, :release_year], unique: true
  end
end
