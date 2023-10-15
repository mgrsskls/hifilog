class RenameManufacturersToBrands < ActiveRecord::Migration[7.0]
  def change
    rename_table :manufacturers, :brands
  end
end
