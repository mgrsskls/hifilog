class RemoveCustomProductUniquenessFromPossessions < ActiveRecord::Migration[7.1]
  def change
    remove_index :possessions, name: 'index_possessions_custom_product_id'
  end
end
