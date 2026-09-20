# frozen_string_literal: true

# The staging area between the importer and the catalogue.
#
# Nothing that a crawler produces is written to `products`. It is written here,
# with a source for every single field, and a person decides. Three tables carry
# that:
#
#   import_batches           one run of the importer
#   import_candidates        one statement about one product, from one source
#   import_category_mappings "this shop's word means this sub category"
#
# The last one exists because of a measurement rather than a guess. In the first
# full run 68% of the candidates carried the shop's own category, and those
# collapsed into 1039 distinct (brand, category) pairs -- one decision covering
# seven products on average, and 1351 in the largest case. A mapping is made one
# time and then applies to every later run, which is what keeps re-crawling
# cheap.
class CreateImportStaging < ActiveRecord::Migration[8.1]
  def change
    create_table :import_batches do |t|
      # What ran, and against what. `source` is "brand_websites" today and names
      # the next source when there is one, so a candidate can always be traced
      # to the kind of place it came from.
      t.string :source, null: false
      t.string :tool_version
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :candidates_count, null: false, default: 0
      t.jsonb :statistics
      t.timestamps
    end

    create_table :import_candidates do |t|
      t.references :import_batch, foreign_key: true
      # The brand is resolved when the row is loaded. A candidate whose brand is
      # gone from the catalogue keeps its slug and waits, rather than being
      # dropped: the brand may come back, and a nil here is a question for the
      # review, not a fault.
      t.references :brand, foreign_key: true
      t.string :brand_slug, null: false

      t.citext :name, null: false
      t.string :variant_name
      t.string :model_no
      t.text :description
      t.decimal :price, precision: 12, scale: 4
      t.string :price_currency
      t.integer :release_year
      t.boolean :discontinued
      t.boolean :diy_kit

      # The catalogue's own sub category, once it is known, and the shop's word
      # for it, which is what the mapping is made from. The two are never mixed:
      # "Subwoofer Outlet" is a shop's word and is never written to the
      # catalogue.
      t.references :sub_category, foreign_key: true
      t.string :source_category

      t.jsonb :custom_attributes
      t.string :image_urls, array: true, default: []
      t.jsonb :variants, default: []

      # Where every field came from, as { field => { source, url, snippet,
      # confidence } }. This is the reason a reviewer can decide in seconds, and
      # the reason a second crawl can show what changed and on whose authority.
      t.jsonb :provenance, null: false, default: {}
      t.decimal :score, precision: 4, scale: 3, null: false, default: 0
      t.string :warnings, array: true, default: []

      t.string :source_url, null: false
      t.string :source_platform
      # The digest of the answer this row was built from. A later run that reads
      # the same unchanged page therefore does no write at all.
      t.string :fingerprint

      # Every spelling under which this may be the same product as another. A
      # shared key is a question for the review, never an automatic merge.
      t.string :match_keys, array: true, default: []

      t.string :status, null: false, default: 'pending'
      t.text :decision_note
      t.references :reviewed_by, foreign_key: { to_table: :admin_users }
      t.datetime :reviewed_at

      # What it became, once it was accepted.
      t.references :product, foreign_key: true
      t.references :product_variant, foreign_key: true

      t.timestamps
    end

    # One row per product page per brand. A second run updates the row rather
    # than adding a second one.
    add_index :import_candidates, %i[brand_slug source_url], unique: true
    # The review queue: the best-sourced pending rows of one brand first.
    add_index :import_candidates, %i[status score], order: { score: :desc }
    add_index :import_candidates, %i[brand_id status]
    add_index :import_candidates, %i[status sub_category_id]
    # "Is this already in the catalogue, under any of its spellings?"
    add_index :import_candidates, :match_keys, using: :gin
    # The mapping screen asks for the pairs that have no mapping yet.
    add_index :import_candidates, %i[brand_id source_category],
              where: 'source_category IS NOT NULL'

    create_table :import_category_mappings do |t|
      # A mapping without a brand is the answer for every brand that writes this
      # word, which is what makes "Amplifiers" or "Headphones" one decision
      # rather than a hundred. A mapping with a brand wins over it, for the shop
      # that means something of its own by the same word.
      t.references :brand, foreign_key: true
      t.citext :source_category, null: false
      t.references :sub_category, foreign_key: true
      # A word that means "no product of this catalogue": a shop's "Vinyl" or
      # "Merch". Recorded as a decision so it is made one time, not once per run.
      t.boolean :out_of_scope, null: false, default: false
      t.references :decided_by, foreign_key: { to_table: :admin_users }
      t.timestamps
    end

    add_index :import_category_mappings, %i[brand_id source_category], unique: true
    add_index :import_category_mappings, :source_category,
              unique: true, where: 'brand_id IS NULL'
  end
end
