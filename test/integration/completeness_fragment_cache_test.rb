# frozen_string_literal: true

require 'test_helper'

# The completeness bar is a display variant of the shared brand / product row partials, which are
# fragment cached. If `render_completeness` is not part of the cache key, the public catalogue and
# the contribute queues share row fragments and whichever page renders first decides whether the
# bar appears — intermittently, and only once a cache is warm.
#
# Fragment caching is off in the test environment, so these tests turn it on for their duration.
# Without that they would pass whether or not the cache keys are correct.
class CompletenessFragmentCacheTest < ActionDispatch::IntegrationTest
  # Bare /products and /brands are browse hubs and render no entity rows, so they cannot exercise
  # the row fragment cache. A sort param puts the same controllers into their list state.
  def catalogue_list_url
    products_url(sort: 'name_asc')
  end

  def brands_list_url
    brands_url(sort: 'name_asc')
  end

  def with_fragment_caching
    original_store = Rails.cache
    original_perform = ActionController::Base.perform_caching

    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActionController::Base.perform_caching = true

    yield
  ensure
    Rails.cache = original_store
    ActionController::Base.perform_caching = original_perform
  end

  test 'the product catalogue does not inherit completeness bars cached by the contribute queue' do
    with_fragment_caching do
      get contribute_incomplete_products_url

      assert_response :success
      assert_select '.Completeness', minimum: 1

      get catalogue_list_url

      assert_response :success
      assert_select '.EntityList--products'
      assert_select '.Completeness', count: 0
    end
  end

  test 'the contribute queue still shows completeness after the catalogue has been cached' do
    with_fragment_caching do
      get catalogue_list_url

      assert_response :success
      assert_select '.EntityList--products'
      assert_select '.Completeness', count: 0

      get contribute_incomplete_products_url

      assert_response :success
      assert_select '.Completeness', minimum: 1
    end
  end

  test 'the brands index does not inherit completeness bars cached by the contribute queue' do
    with_fragment_caching do
      get contribute_incomplete_brands_url

      assert_response :success
      assert_select '.Completeness', minimum: 1

      get brands_list_url

      assert_response :success
      assert_select '.EntityList--brands'
      assert_select '.Completeness', count: 0
    end
  end

  test 'the contribute brand queue still shows completeness after the brands index is cached' do
    with_fragment_caching do
      get brands_list_url

      assert_response :success
      assert_select '.EntityList--brands'
      assert_select '.Completeness', count: 0

      get contribute_incomplete_brands_url

      assert_response :success
      assert_select '.Completeness', minimum: 1
    end
  end
end
