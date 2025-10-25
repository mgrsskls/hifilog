require 'test_helper'

class BookmarksControllerTest < ActionDispatch::IntegrationTest
  test 'create with product' do
    user = users(:one)
    bookmarks_count = user.bookmarks.count
    product = Product.create!(name: 'name', sub_categories: [sub_categories(:one)], brand: brands(:one))

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
end
