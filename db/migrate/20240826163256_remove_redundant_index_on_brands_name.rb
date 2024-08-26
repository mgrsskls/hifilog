class RemoveRedundantIndexOnBrandsName < ActiveRecord::Migration[7.1]
  def change
    remove_index :brands, name: 'index_brands_name'
  end
end
