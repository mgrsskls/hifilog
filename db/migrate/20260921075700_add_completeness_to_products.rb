# frozen_string_literal: true

# Unlike brands (see AddCompletenessToBrands), a product's completeness cannot be a generated
# column: applicable_highlighted_attributes reaches through sub_categories into
# custom_attributes_sub_categories and custom_attributes.highlighted, and Postgres generated
# columns may only reference the same row. specs_applicable / specs_filled come from the same
# join (see contribute_product_items_v03.sql's `spec` LATERAL) and are stored alongside
# completeness for the same reason -- ContributeProductItem.missing_specs reads them.
#
# Kept in sync by Product (on save and on sub_categories changes) and by CustomAttribute (on
# `highlighted` changing or its sub_categories changing) -- see Product#recalculate_completeness!
# and CustomAttribute's after_commit/habtm callbacks. Existing rows are backfilled by
# `bin/rails completeness:backfill_products` after this migration runs.
class AddCompletenessToProducts < ActiveRecord::Migration[8.1]
  def change
    change_table :products, bulk: true do |t|
      t.integer :completeness, null: false, default: 0
      t.integer :specs_applicable, null: false, default: 0
      t.integer :specs_filled, null: false, default: 0
      t.index :completeness
    end
  end
end
