class AddDefaultValueToProductVariantName < ActiveRecord::Migration[7.1]
  def change
    change_column :product_variants, :name, :string, null: false, default: ""
  end
end
