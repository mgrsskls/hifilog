class RenameManufacturerIdToBrandIdInProductsTable < ActiveRecord::Migration[7.0]
  def change
    rename_column :products, :manufacturer_id, :brand_id
  end
end
