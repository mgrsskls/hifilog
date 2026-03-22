class AddBookmarkListsIdBookmarksBookmarkListIdFk < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :bookmarks, :bookmark_lists, column: :bookmark_list_id, primary_key: :id
  end
end
