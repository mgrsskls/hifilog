class AddIndexToBookmarksOnBookmarkLists < ActiveRecord::Migration[7.2]
  def change
    add_index :bookmarks, :bookmark_list_id
  end
end
