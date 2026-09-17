# frozen_string_literal: true

# The home page reads the newest rows of two tables that had no index for that order: versions
# (the "Last edits" list, and the contributor count of the pulse line) and possessions (the photo
# mosaic). Both tables only grow, and this is the most requested page of the site, so neither
# query may fall back to a sequential scan.
class AddHomeHighlightIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :versions, :created_at, algorithm: :concurrently
    # Matches Possession.recent_preview's order exactly -- a plain ascending index scanned
    # backwards gives DESC NULLS FIRST, which is not the order the scope asks for.
    add_index :possessions, :created_at, order: { created_at: 'DESC NULLS LAST' },
                                         algorithm: :concurrently
  end
end
