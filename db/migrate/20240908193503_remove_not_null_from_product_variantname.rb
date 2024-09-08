class RemoveNotNullFromProductVariantname < ActiveRecord::Migration[7.2]
  def change
    change_column :product_variants, :name, :citext
  end
end
