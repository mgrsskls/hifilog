class RenameBrandsCountryToCountryCode < ActiveRecord::Migration[7.1]
  def change
    rename_column :brands, :country, :country_code
  end
end
