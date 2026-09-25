# frozen_string_literal: true

# The series that a product version adds the product to or removes it from: the old and the new
# product_series_id. The series changelog reads the product versions through this column, because
# object_changes is YAML text and can not be searched with an index. See docs/product-series.md,
# "Changelog". Existing versions are backfilled by `bin/rails versions:backfill_product_series_ids`.
class AddProductSeriesIdsToVersions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :versions, :product_series_ids, :bigint, array: true
    add_index :versions, :product_series_ids, using: :gin, algorithm: :concurrently
  end
end
