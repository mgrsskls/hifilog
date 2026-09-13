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
    # 52 rows total: the 51 created here, plus the brand_follows fixture's Feliks Audio catalog
    # entry riding along on users(:one)'s feed.
    assert_select '.Feed-item', count: 2
  end
  test 'a followed brand with a logo shows the logo instead of the verb icon' do
    user = users(:one)
    brand = brands(:two)
    brand.logo.attach(**one_by_one_png_upload(filename: 'brand-logo.png'))
    follow_at = Time.zone.local(2026, 6, 1, 9, 0, 0)
    travel_to(follow_at) { BrandFollow.create!(user:, brand:) }
    travel_to(follow_at + 1.day) do
      Product.create!(name: "Logo Row #{SecureRandom.hex(4)}", brand:, sub_category_ids: [sub_categories(:one).id])
    end

    sign_in user
    get dashboard_feed_path

    assert_response :success
    assert_select '.Feed-iconContainer--logo img.Feed-brandLogo', minimum: 1
  end

  test 'a followed brand without a logo keeps the verb icon' do
    user = users(:one)
    brand = brands(:three)
    brand.logo.purge if brand.logo.attached?
    follow_at = Time.zone.local(2026, 6, 1, 9, 0, 0)
    travel_to(follow_at) { BrandFollow.create!(user:, brand:) }
    travel_to(follow_at + 1.day) do
      Product.create!(name: "Icon Row #{SecureRandom.hex(4)}", brand:, sub_category_ids: [sub_categories(:one).id])
    end

    sign_in user
    get dashboard_feed_path

    assert_response :success
    assert_select '.Feed-iconContainer--logo', count: 0
    assert_select '.Feed-iconContainer svg.Feed-icon', minimum: 1
  end
end
