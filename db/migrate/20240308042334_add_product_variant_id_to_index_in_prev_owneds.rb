class AddProductVariantIdToIndexInPrevOwneds < ActiveRecord::Migration[7.1]
  def change
    remove_index :prev_owneds, name: 'index_prev_owneds_on_product_id_and_user_id'
    add_index :prev_owneds, [:product_id, :user_id, :product_variant_id], unique: true
  end
end
