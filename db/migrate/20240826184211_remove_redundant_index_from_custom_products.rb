class RemoveRedundantIndexFromCustomProducts < ActiveRecord::Migration[7.1]
  def change
    remove_index :custom_products, name: 'index_custom_products_on_user_id'
  end
end
