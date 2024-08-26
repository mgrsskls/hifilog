class RemoveGinIndexProductsOnNameIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index nil, name: 'gin_index_products_on_name'
  end
end
