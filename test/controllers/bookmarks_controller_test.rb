# frozen_string_literal: true

require 'test_helper'

class BookmarksControllerTest < ActionDispatch::IntegrationTest
  test 'create with product' do
    user = users(:one)
    bookmarks_count = user.bookmarks.count
    product = products(:two)

    post bookmarks_path(product_id: product.id)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    post bookmarks_path(product_id: product.id)

    assert_equal bookmarks_count + 1, Bookmark.where(user_id: user.id).count
    assert_response :redirect
    assert_redirected_to product_url(id: product.friendly_id)
  end

  test 'create with product variant' do
    user = users(:one)
    product_variant = product_variants(:two)
    bookmarks_count = user.bookmarks.count

    post bookmarks_path(product_variant_id: product_variant.id)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    post bookmarks_path(product_variant_id: product_variant.id)

    assert_equal bookmarks_count + 1, user.bookmarks.count
    assert_response :redirect
    assert_redirected_to product_variant_url(
      id: product_variant.friendly_id,
      product_id: product_variant.product.friendly_id
    )
  end

  test 'destroy with product' do
    user = users(:one)
    bookmark = user.bookmarks.first
    bookmarks_count = user.bookmarks.count

    delete bookmark_path(bookmark)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    delete bookmark_path(bookmark)

    assert_equal bookmarks_count - 1, user.bookmarks.count
    assert_response :redirect
    assert_redirected_to dashboard_bookmarks_path
  end

  test 'destroy with product variant' do
    user = users(:one)
    product_variant = product_variants(:two)
    bookmark = Bookmark.new(item_id: product_variant.id, item_type: 'ProductVariant')
    user.bookmarks << bookmark
    user.save!

    bookmarks_count = user.bookmarks.count

    delete bookmark_path(bookmark)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    delete bookmark_path(bookmark)

    assert_equal bookmarks_count - 1, user.bookmarks.count
    assert_response :redirect
    assert_redirected_to dashboard_bookmarks_path
  end

  test 'create with event redirects to events' do
    user = users(:one)

    event = Event.create!(
      name: 'New bookmark event',
      address: 'a',
      url: 'https://example.test/bm',
      country_code: 'US',
      start_date: Time.zone.today + 400,
      end_date: Time.zone.today + 401
    )

    sign_in user

    assert_difference(-> { user.bookmarks.where(item_type: 'Event', item_id: event.id).count }, 1) do
      post bookmarks_path(event_id: event.id)
    end

    assert_redirected_to events_path
  end

  test 'create with brand redirects to brand page' do
    user = users(:one)
    brand = brands(:one)

    sign_in user

    post bookmarks_path(brand_id: brand.id)

    assert user.bookmarks.exists?(item_type: 'Brand', item_id: brand.id)
    assert_redirected_to brand_path(id: brand.friendly_id)
  end

  test 'create duplicate bookmark sets alert flash' do
    user = users(:one)
    product = products(:two)

    sign_in user

    post bookmarks_path(product_id: product.id)
    assert_redirected_to product_url(id: product.friendly_id)

    post bookmarks_path(product_id: product.id)
    assert_redirected_to product_url(id: product.friendly_id)
    assert flash[:alert].present?
  end

  test 'update assigns bookmark list' do
    user = users(:one)
    bookmark = bookmarks(:with_product)

    sign_in user

    patch bookmark_path(bookmark), params: { bookmark_list_id: bookmark_lists(:two).id }

    assert_redirected_to dashboard_bookmarks_path
    assert_equal bookmark_lists(:two).id, bookmark.reload.bookmark_list_id
  end

  test 'update clears bookmark list when id omitted' do
    user = users(:one)
    bookmark = bookmarks(:with_product)

    sign_in user

    patch bookmark_path(bookmark), params: { bookmark_list_id: bookmark_lists(:two).id }
    patch bookmark_path(bookmark), params: {}

    assert_redirected_to dashboard_bookmarks_path
    assert_nil bookmark.reload.bookmark_list_id
  end

  test 'update and destroy honor redirect_to' do
    user = users(:one)
    bookmark = bookmarks(:with_product)
    target = products_path

    sign_in user

    patch bookmark_path(bookmark), params: { redirect_to: target, bookmark_list_id: bookmark_lists(:one).id }

    assert_redirected_to target

    delete bookmark_path(bookmark), params: { redirect_to: target }

    assert_redirected_to target
  end
end
