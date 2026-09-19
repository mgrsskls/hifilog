# frozen_string_literal: true

# The brand page lists the newest products of a brand (BrandLatestProducts.products). This index
# has the same order as Product::NEWEST_FIRST_ORDER_SQL, so PostgreSQL reads the first rows of
# the brand from the index and does not sort all products of the brand.
class AddNewestFirstIndexToProducts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :products,
              'brand_id, release_year DESC NULLS LAST, release_month DESC NULLS LAST, ' \
              'release_day DESC NULLS LAST, created_at DESC, id DESC',
              name: 'index_products_on_brand_newest_first',
              algorithm: :concurrently
  end
end
