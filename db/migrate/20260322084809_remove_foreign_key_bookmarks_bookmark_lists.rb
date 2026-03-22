class RemoveForeignKeyBookmarksBookmarkLists < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :bookmarks, :bookmark_lists
  end
end
