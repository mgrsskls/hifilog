class AddIndexToUserBookmarkLists < ActiveRecord::Migration[7.2]
  def change
    add_index :bookmark_lists, :user_id
  end
end
