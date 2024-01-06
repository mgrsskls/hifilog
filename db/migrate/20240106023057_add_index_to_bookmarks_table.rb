class AddIndexToBookmarksTable < ActiveRecord::Migration[7.0]
  def change
    add_index :bookmarks, [:product_id, :user_id], unique: true
  end
end
