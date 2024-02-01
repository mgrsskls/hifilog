class ChangeBrandNameIndexToCaseInsensitive < ActiveRecord::Migration[7.1]
  def change
    remove_index :brands, name: 'index_brands_on_name'
    add_index :brands, 'lower(name)', name: 'index_brands_on_name', unique: true
  end
end
