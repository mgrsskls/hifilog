class ChangeBookmarksItemIdNullConstraint < ActiveRecord::Migration[8.1]
  def change
    change_column_null :bookmarks, :item_id, false
  end
end
