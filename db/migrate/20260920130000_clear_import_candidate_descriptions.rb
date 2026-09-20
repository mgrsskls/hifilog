# The description of a product is written by people. The importer copied the
# shop's own text into it, and that text is removed here from every candidate
# that no person has edited. An edited row keeps its description, because a
# person may have written it. The importer no longer fills the field.
class ClearImportCandidateDescriptions < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE import_candidates
      SET description = NULL, provenance = provenance - 'description'
      WHERE edited_at IS NULL
        AND (description IS NOT NULL OR provenance ? 'description')
    SQL
  end

  def down
    # The shop text is not kept anywhere; a new crawl would be needed.
  end
end
