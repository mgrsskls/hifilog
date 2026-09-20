# The verdict of the second reading, as a column. Before this, a candidate kept
# only the time and the note of its check, so a row read as out of scope stayed
# in the review queue, and `rake import:map` could give it a sub category again.
# `rake import:load` now rejects those rows, and `rake import:map` leaves every
# row alone whose verdict already decided its sub categories.
class AddValidationVerdictToImportCandidates < ActiveRecord::Migration[8.1]
  def change
    add_column :import_candidates, :validation_verdict, :string
  end
end
