class AddCountryToBrands < ActiveRecord::Migration[7.1]
  def change
    add_column :brands, :country, :string
  end
end
