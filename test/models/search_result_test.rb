# frozen_string_literal: true

require 'test_helper'

class SearchResultTest < ActiveSupport::TestCase
  test 'search exposes pg_search scope backed by immutable rows' do
    assert_respond_to SearchResult, :search_by_name

    skip 'search_results view lacks rows yet' unless SearchResult.exists?

    hit = SearchResult.first

    assert_predicate hit, :readonly?

    scoped = SearchResult.search_by_name(products(:one).name)
    assert_kind_of ActiveRecord::Relation, scoped
  end
end
