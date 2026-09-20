# frozen_string_literal: true

# A product belongs to more than one sub category, and so must a candidate.
#
# `Product has_and_belongs_to_many :sub_categories` from the beginning, and the
# catalogue needs it: the Wisdom Audio SUB1 is a subwoofer and an in-wall
# loudspeaker, and a reviewer who can only choose one has to choose wrongly.
# Staging modelled a single one, which would have quietly thrown the second
# answer away at every promotion.
#
# An array of ids rather than a join table. Staging rows are written in bulk,
# read as whole rows by the review, and deleted together; a join table would
# add a second write for each row and a join to every screen, and buy nothing,
# because nothing else in the application references a candidate's categories.
# `products_sub_categories` remains the real relationship; this is the proposal
# that fills it.
class ImportCandidatesHaveManySubCategories < ActiveRecord::Migration[8.1]
  def up
    add_column :import_candidates, :sub_category_ids, :bigint, array: true, default: [], null: false
    add_column :import_category_mappings, :sub_category_ids, :bigint, array: true, default: [], null: false

    # Whatever was decided under the single column is kept.
    execute <<~SQL.squish
      UPDATE import_candidates SET sub_category_ids = ARRAY[sub_category_id]
      WHERE sub_category_id IS NOT NULL
    SQL
    execute <<~SQL.squish
      UPDATE import_category_mappings SET sub_category_ids = ARRAY[sub_category_id]
      WHERE sub_category_id IS NOT NULL
    SQL

    remove_column :import_candidates, :sub_category_id
    remove_column :import_category_mappings, :sub_category_id

    # "Which candidates are already classified" is the review's first question,
    # and `sub_category_ids <> '{}'` cannot use a btree index. GIN answers both
    # that and "which candidates are subwoofers".
    add_index :import_candidates, :sub_category_ids, using: :gin
  end

  def down
    add_reference :import_candidates, :sub_category, foreign_key: true
    add_reference :import_category_mappings, :sub_category, foreign_key: true
    execute <<~SQL.squish
      UPDATE import_candidates SET sub_category_id = sub_category_ids[1]
      WHERE array_length(sub_category_ids, 1) > 0
    SQL
    execute <<~SQL.squish
      UPDATE import_category_mappings SET sub_category_id = sub_category_ids[1]
      WHERE array_length(sub_category_ids, 1) > 0
    SQL
    remove_column :import_candidates, :sub_category_ids
    remove_column :import_category_mappings, :sub_category_ids
  end
end
