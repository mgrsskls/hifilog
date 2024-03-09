class AddProductToIndexOnProductVariants < ActiveRecord::Migration[7.1]
  def change
    change_column :product_variants, :name, :string, null: false
    add_index :product_variants, [:name, :product_id], unique: true
  end
end
