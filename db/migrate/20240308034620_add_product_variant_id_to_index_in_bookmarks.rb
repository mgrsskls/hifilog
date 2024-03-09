class AddProductVariantIdToIndexInBookmarks < ActiveRecord::Migration[7.1]
  def change
    remove_index :bookmarks, name: 'index_bookmarks_on_product_id_and_user_id'
    add_index :bookmarks, [:product_id, :user_id, :product_variant_id], unique: true
  end
end
