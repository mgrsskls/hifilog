class AddBookmarksItemIdItemTypeIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :bookmarks, %w[item_id item_type], name: :index_bookmarks_item_id_item_type
  end
end
