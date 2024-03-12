class AllowMultiplePossessionsOfOneProduct < ActiveRecord::Migration[7.1]
  def change
    remove_index :possessions, name: 'idx_on_product_id_user_id_product_variant_id_9e45f66b35'
    add_index :possessions, [:product_id, :product_variant_id, :user_id]
  end
end
