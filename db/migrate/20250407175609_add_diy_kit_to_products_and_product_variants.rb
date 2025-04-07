class AddDiyKitToProductsAndProductVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :diy_kit, :boolean
    add_column :product_variants, :diy_kit, :boolean
  end
end
