class AddGinIndexToProductsAndBrands < ActiveRecord::Migration[7.1]
  def change
    enable_extension "pg_trgm"

    add_index :products,
              :name,
              using: :gin,
              opclass: 'gin_trgm_ops',
              name: 'gin_index_products_on_name'

    add_index :brands,
              :name,
              using: :gin,
              opclass: 'gin_trgm_ops',
              name: 'gin_index_brands_on_name'
  end
end
