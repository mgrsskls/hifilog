# frozen_string_literal: true

require 'test_helper'

class UserControllerTest < ActionDispatch::IntegrationTest
  test 'dashboard' do
    get dashboard_root_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_root_path
    assert_response :success
    assert_select '.UserDashboard-feed'
    assert_select '.UserDashboard-statistics .StatisticsNumbers'
    assert_match 'You currently own', @response.body
    assert_select '.UserDashboard-events'
    assert_select '.UserDashboard-newest'
    assert_select 'a[href=?]', dashboard_feed_path
    assert_select 'a[href=?]', dashboard_statistics_root_path
  end

  test 'feed' do
    get dashboard_feed_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_feed_path
    assert_response :success
    assert_select 'h1', text: I18n.t('headings.feed')
    assert_select '.Feed, .EmptyState'
    assert_select 'a.Sidebar-link[href=?][aria-current="true"]', dashboard_feed_path
    assert_select 'nav .Tabs', count: 0
  end

  test 'feed shows invalid page as first page' do
    sign_in users(:one)

    get dashboard_feed_path(page: 999)
    assert_response :success
    assert_select 'h1', text: I18n.t('headings.feed')
  end

  test 'feed paginates at fifty rows per page' do
    user = users(:one)
    sign_in user

    51.times do |index|
      travel_to(Time.zone.local(2026, 10, 1) + index.days) do
        CustomProduct.create!(
          name: "Feed pagination #{index}",
          user: user,
          sub_categories: [sub_categories(:one)]
        )
      end
    end

    get dashboard_feed_path
    assert_response :success
    assert_select '.Pagination'

    get dashboard_feed_path(page: 2)
    assert_response :success
    assert_select '.Feed-item', count: 1
  end

  test 'products' do
    get dashboard_products_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_products_path
    assert_response :success

    get dashboard_products_path(category: 'headphone-amplifiers')
    assert_response :success
  end

  test 'bookmarks' do
    get dashboard_bookmarks_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_bookmarks_path
    assert_response :success

    get dashboard_bookmarks_path(category: 'headphone-amplifiers')
    assert_response :success

    get dashboard_bookmarks_path(id: bookmark_lists(:one).id)
    assert_response :success
  end

  test 'prev_owneds' do
    get dashboard_prev_owneds_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_prev_owneds_path
    assert_response :success

    get dashboard_prev_owneds_path(category: 'headphone-amplifiers')
    assert_response :success
  end

  test 'contributions' do
    get dashboard_contributions_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_contributions_path
    assert_response :success
  end

  test 'history' do
    get dashboard_history_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_history_path
    assert_response :success
  end

  test 'statistics' do
    get dashboard_statistics_root_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_statistics_root_path
    assert_response :success
  end

  test 'has' do
    get has_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get has_path

    res = JSON.parse(@response.body)
    assert_nil res[:brands]
    assert_nil res[:products]
    assert_nil res[:product_variants]
    assert_response :success

    get has_path, params: {
      brands: [brands(:one).id, brands(:two).id],
      products: [products(:one).id, products(:two).id],
      product_variants: [product_variants(:one).id, product_variants(:two).id]
    }

    res = JSON.parse(@response.body)
    assert_equal [
      { 'id' => brands(:one).id, 'in_collection' => true, 'previously_owned' => false, 'bookmarked' => true },
      { 'id' => brands(:two).id, 'in_collection' => false, 'previously_owned' => true, 'bookmarked' => false }
    ], res['brands']
    assert_equal [
      { 'id' => products(:one).id, 'in_collection' => true, 'previously_owned' => false, 'bookmarked' => true },
      { 'id' => products(:two).id, 'in_collection' => false, 'previously_owned' => true, 'bookmarked' => false }
    ], res['products']
    assert_equal [
      { 'id' => product_variants(:one).id, 'in_collection' => true, 'previously_owned' => false,
        'bookmarked' => true },
      { 'id' => product_variants(:two).id, 'in_collection' => false, 'previously_owned' => true, 'bookmarked' => false }
    ], res['product_variants']
    assert_response :success

    get has_path, params: { events: [events(:one).id] }

    res = JSON.parse(@response.body)
    payload = res['events'].sole

    assert_equal events(:one).id, payload['id']
    assert_equal false, payload['in_collection']
    assert_equal true, payload['previously_owned']
    assert_equal false, payload['bookmarked']
  end

  test 'events' do
    get dashboard_events_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_events_path
    assert_response :success

    get dashboard_events_path(country: 'DE')
    assert_response :success
  end

  test 'past_events' do
    get dashboard_past_events_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_past_events_path
    assert_response :success

    get dashboard_past_events_path(year: Time.zone.today.year)
    assert_response :success
  end

  test 'counts' do
    get counts_path

    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get counts_path
    res = JSON.parse(@response.body)
    Rails.logger.debug { "Counts response: #{res.inspect}" }
    assert_equal 3, res['products']
    assert_equal 3, res['custom_products']
    assert_equal 3, res['previous_products']
    assert_equal 2, res['setups']
    assert_equal 4, res['bookmarks']
    assert_equal 1, res['events']
    assert_equal 1, res['notes']
    assert_response :success
  end
end
