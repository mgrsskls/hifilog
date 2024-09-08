class RemoveNotNullFromProductVariantName < ActiveRecord::Migration[7.2]
  def change
    change_column :product_variants, :name, :citext, null: true
  end
end
