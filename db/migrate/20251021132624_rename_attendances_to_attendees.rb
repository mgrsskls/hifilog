class RenameAttendancesToAttendees < ActiveRecord::Migration[8.0]
  def change
    rename_table :event_attendances, :event_attendees
  end
end
