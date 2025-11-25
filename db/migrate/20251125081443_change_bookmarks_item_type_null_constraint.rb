class ChangeBookmarksItemTypeNullConstraint < ActiveRecord::Migration[8.1]
  def change
    change_column_null :bookmarks, :item_type, false
  end
end
