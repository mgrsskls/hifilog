class RemoveIndexProductsOnBrandIdIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index 'products', name: 'index_products_on_brand_id'
  end
end
