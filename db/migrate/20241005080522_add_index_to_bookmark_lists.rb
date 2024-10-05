class AddIndexToBookmarkLists < ActiveRecord::Migration[7.2]
  def change
    add_index :bookmark_lists, [:name, :user_id], unique: true
  end
end
