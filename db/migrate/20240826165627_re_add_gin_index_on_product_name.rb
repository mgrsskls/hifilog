class ReAddGinIndexOnProductName < ActiveRecord::Migration[7.1]
  def change
    add_index :products,
              :name,
              using: :gin,
              opclass: 'gin_trgm_ops',
              name: 'gin_index_products_on_name'
  end
end
