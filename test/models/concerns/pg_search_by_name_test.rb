# frozen_string_literal: true

require 'test_helper'

class PgSearchByNameTest < ActiveSupport::TestCase
  test 'defines search_by_name scopes on searchable models' do
    assert_respond_to Product, :search_by_name
    assert_respond_to Brand, :search_by_name
    assert_respond_to ProductVariant, :search_by_name
    assert_respond_to ProductItem, :search_by_name
    assert_respond_to SearchResult, :search_by_name
  end

  test 'search_by_name returns matching products and respects prefix-style tokens' do
    hits = Product.search_by_name('Elise')

    assert_includes hits.map(&:slug), products(:one).slug
  end

  test 'search_by_name matches brand metadata on catalogue rows' do
    hits = Brand.search_by_name('Feliks')

    assert_includes hits.map(&:slug), brands(:one).slug
  end
end
