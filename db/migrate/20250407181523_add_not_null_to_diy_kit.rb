class AddNotNullToDiyKit < ActiveRecord::Migration[8.0]
  def change
    Product.update_all(diy_kit: false)
    ProductVariant.update_all(diy_kit: false)

    change_column :products, :diy_kit, :boolean, null: false, default: false
    change_column :product_variants, :diy_kit, :boolean, null: false, default: false
  end
end
