# frozen_string_literal: true

require 'test_helper'

class Dashboard::FeedControllerTest < ActionDispatch::IntegrationTest
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
end
