class AddForeignKeysToBookmarkLists < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :bookmark_lists, :users
  end
end
