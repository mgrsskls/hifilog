class RemoveRedundantIndexFromPossessions < ActiveRecord::Migration[8.1]
  def change
    remove_index :possessions, name: "index_possessions_on_custom_product_id_and_user_id"
  end
end
