class RemoveRedundantIndices < ActiveRecord::Migration[8.1]
  def change
    remove_index :event_attendees, name: "index_event_attendees_on_user_id"
    remove_index :bookmarks, name: "index_bookmarks_on_user_id"
  end
end
