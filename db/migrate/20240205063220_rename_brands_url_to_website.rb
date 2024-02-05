class RenameBrandsUrlToWebsite < ActiveRecord::Migration[7.1]
  def change
    rename_column :brands, :url, :website
  end
end
