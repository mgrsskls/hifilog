# frozen_string_literal: true

# Splits the jobs `name` + `full_name` were sharing (see the Brand section of README.md):
#
#   name          canonical display identity, e.g. "Fezz Audio" -- unchanged here
#   abbreviation  short form the brand is known by that is NOT part of the name, e.g. "B&O"
#   legal_name    registered company name, e.g. "Bang & Olufsen AS"
#
# `full_name` is left in place; the follow-up migration classifies its values into the two
# new columns, and it is dropped in a later release once the leftovers are reviewed.
class AddAbbreviationAndLegalNameToBrands < ActiveRecord::Migration[8.1]
  def change
    # citext to match `name`, so abbreviation comparisons and lookups are case-insensitive
    # for free rather than needing LOWER() everywhere.
    add_column :brands, :abbreviation, :citext
    add_column :brands, :legal_name, :string

    # Mirrors index_brands_on_full_name_trgm: abbreviation is searched by the same fuzzy
    # pg_search scope that name is, so it needs the same trigram index.
    add_index :brands, :abbreviation, using: :gin, opclass: :gin_trgm_ops,
                                      name: 'index_brands_on_abbreviation_trgm'
  end
end
