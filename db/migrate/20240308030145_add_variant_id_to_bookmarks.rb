class AddVariantIdToBookmarks < ActiveRecord::Migration[7.1]
  def change
    add_column :bookmarks, :variant_id, :bigint
    add_column :prev_owneds, :variant_id, :bigint
  end
end
