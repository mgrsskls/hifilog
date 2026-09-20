# `rake import:load` wrote three jsonb columns as JSON text, so each value was
# stored as one JSON string ("{\"name\": ...}") instead of an object. The
# review screen then fails on the provenance, and a promotion would copy the
# text into the product's custom attributes.
#
# This decodes each string value back into the object it holds. It changes only
# rows where the column is a JSON string, so it is safe to run again.
class DecodeImportCandidateJsonColumns < ActiveRecord::Migration[8.1]
  COLUMNS = %w[custom_attributes variants provenance].freeze

  def up
    COLUMNS.each do |column|
      execute <<~SQL.squish
        UPDATE import_candidates
        SET #{column} = (#{column} #>> '{}')::jsonb
        WHERE jsonb_typeof(#{column}) = 'string'
      SQL
    end
  end

  def down
    # Nothing to undo: the encoded form was the error.
  end
end
