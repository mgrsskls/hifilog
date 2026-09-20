# A person can now correct a candidate by hand before approving it. The next
# `rake import:load` and `rake import:map` must not undo that correction, so an
# edited row is marked, and both tasks leave a marked row alone.
class AddEditedToImportCandidates < ActiveRecord::Migration[8.1]
  def change
    add_column :import_candidates, :edited_at, :datetime
    add_reference :import_candidates, :edited_by, foreign_key: { to_table: :admin_users }, index: false
  end
end
