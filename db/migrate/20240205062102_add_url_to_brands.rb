class AddUrlToBrands < ActiveRecord::Migration[7.1]
  def change
    add_column :brands, :url, :string
  end
end
