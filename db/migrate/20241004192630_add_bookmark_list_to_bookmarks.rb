class AddBookmarkListToBookmarks < ActiveRecord::Migration[7.2]
  def change
    add_column :bookmarks, :bookmark_list_id, :bigint
  end
end
