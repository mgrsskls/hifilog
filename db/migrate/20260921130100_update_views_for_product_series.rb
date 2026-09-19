# frozen_string_literal: true

# View versions for product series (docs/product-series.md):
#
# * product_items v23: product_series_id and series_name.
# * contribute_product_items v05: product_series_id and series_name, mirroring product_items v23
#   (see ContributeProductItemTest). Built on top of v04's stored-completeness columns rather than
#   v03's LATERAL, since v04 landed first (see UpdateContributeProductItemsToVersion4).
# * search_results v08: series rows, and series_name on product and variant rows.
class UpdateViewsForProductSeries < ActiveRecord::Migration[8.1]
  def up
    update_view :product_items, version: 23, revert_to_version: 22
    update_view :contribute_product_items, version: 5, revert_to_version: 4
    update_view :search_results, version: 8, revert_to_version: 7
  end

  def down
    # series_catalog_events existed in an earlier version of this migration (series follows were
    # removed before release). A database that ran that version still has the view.
    execute 'DROP VIEW IF EXISTS series_catalog_events'
    update_view :search_results, version: 7, revert_to_version: 8
    update_view :contribute_product_items, version: 4, revert_to_version: 5
    update_view :product_items, version: 22, revert_to_version: 23
  end
end
