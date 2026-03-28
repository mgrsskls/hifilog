class RemoveLowCardinalityIndexes < ActiveRecord::Migration[8.1]
  def change
    # Remove low-cardinality-only indexes from brands
    remove_index :brands, name: "index_brands_on_discontinued" if index_exists?(:brands, name: "index_brands_on_discontinued")
    
    # Remove redundant event_attendees indexes (keep only the unique composite)
    remove_index :event_attendees, name: "index_event_attendees_on_event_id_and_user_id" if index_exists?(:event_attendees, name: "index_event_attendees_on_event_id_and_user_id")
    remove_index :event_attendees, name: "index_event_attendees_on_event_id" if index_exists?(:event_attendees, name: "index_event_attendees_on_event_id")
  end
end
