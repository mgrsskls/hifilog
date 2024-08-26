class RemoveIndexBookmarksOnProductIdIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index nil, name: 'index_bookmarks_on_product_id'
  end
end
