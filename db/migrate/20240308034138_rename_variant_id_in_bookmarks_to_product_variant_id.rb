class RenameVariantIdInBookmarksToProductVariantId < ActiveRecord::Migration[7.1]
  def change
    rename_column :bookmarks, :variant_id, :product_variant_id
    rename_column :prev_owneds, :variant_id, :product_variant_id
  end
end
