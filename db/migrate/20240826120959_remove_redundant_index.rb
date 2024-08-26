class RemoveRedundantIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index :possessions, name: 'index_possessions_on_user_id_and_custom_product_id'
  end
end
