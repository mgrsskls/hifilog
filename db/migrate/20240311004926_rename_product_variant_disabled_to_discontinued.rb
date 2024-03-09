class RenameProductVariantDisabledToDiscontinued < ActiveRecord::Migration[7.1]
  def change
    rename_column :product_variants, :disabled, :discontinued
  end
end
