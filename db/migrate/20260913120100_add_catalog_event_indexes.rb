# frozen_string_literal: true

# The feed reads new catalog entries by brand and date. The existing indexes do not serve that:
# products has (brand_id, discontinued) and a bare (created_at), and neither can answer
# "this brand's entries, newest first" without a scan.
class AddCatalogEventIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :products, [:brand_id, :created_at], algorithm: :concurrently
    add_index :product_variants, [:product_id, :created_at], algorithm: :concurrently
  end
end
