class AddIndexToBrands < ActiveRecord::Migration[7.0]
  def change
    add_index :brands, :name, unique: true
  end
end
