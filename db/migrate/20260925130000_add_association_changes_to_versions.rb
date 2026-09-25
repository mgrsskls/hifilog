# frozen_string_literal: true

# Changes of associations that are not columns, in the same form as object_changes:
# { "sub_category_ids" => [[old ids], [new ids]] }. PaperTrail records only the columns of a model.
# See docs/catalog-model.md, "Changelog".
class AddAssociationChangesToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :versions, :association_changes, :jsonb
  end
end
