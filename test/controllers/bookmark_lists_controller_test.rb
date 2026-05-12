# frozen_string_literal: true

require 'test_helper'

class BookmarkListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bookmark_list = bookmark_lists(:one)
  end

  test 'should get new' do
    get dashboard_new_bookmark_list_url

    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_new_bookmark_list_url
    assert_response :success
  end

  test 'should create bookmark_list' do
    post bookmark_lists_url, params: { bookmark_list: {
      name: 'Bookmark list'
    } }

    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    assert_difference('BookmarkList.count') do
      post bookmark_lists_url, params: { bookmark_list: {
        name: 'Bookmark list'
      } }
    end

    assert_redirected_to dashboard_bookmark_list_url(BookmarkList.last)
  end

  test 'should show bookmark_list' do
    get dashboard_bookmark_list_url(@bookmark_list)

    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_bookmark_list_url(@bookmark_list)
    assert_response :success

    get dashboard_bookmark_list_url(@bookmark_list), params: {
      category: products(:one).sub_categories.first.slug
    }
    assert_response :success
  end

  test 'should get edit' do
    get dashboard_edit_bookmark_list_url(@bookmark_list)

    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_edit_bookmark_list_url(@bookmark_list)
    assert_response :success
  end

  test 'should update bookmark_list' do
    patch bookmark_list_url(@bookmark_list), params: { bookmark_list: {
      name: 'New name'
    } }

    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    patch bookmark_list_url(@bookmark_list), params: { bookmark_list: {
      name: 'New name'
    } }
    assert_redirected_to dashboard_bookmark_list_url(@bookmark_list)
  end

  test 'should destroy bookmark_list' do
    delete bookmark_list_url(@bookmark_list)

    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    assert_difference('BookmarkList.count', -1) do
      delete bookmark_list_url(@bookmark_list)
    end

    assert_redirected_to dashboard_bookmarks_url
  end

  test 'destroy keeps bookmarks when remove_bookmarks is not set' do
    sign_in users(:one)
    bookmark = bookmarks(:with_product)
    assert_equal @bookmark_list.id, bookmark.bookmark_list_id

    assert_difference('BookmarkList.count', -1) do
      assert_no_difference('Bookmark.count') do
        delete bookmark_list_url(@bookmark_list)
      end
    end

    assert_redirected_to dashboard_bookmarks_url
    assert_equal I18n.t('bookmark_list.messages.deleted_keep_bookmarks', name: @bookmark_list.name),
                 flash[:notice]
    bookmark.reload
    assert_nil bookmark.bookmark_list_id
  end

  test 'destroy removes bookmarks when remove_bookmarks is true' do
    sign_in users(:one)
    bookmark = bookmarks(:with_product)
    assert_equal @bookmark_list.id, bookmark.bookmark_list_id

    assert_difference(['BookmarkList.count', 'Bookmark.count'], -1) do
      delete bookmark_list_url(@bookmark_list, remove_bookmarks: true)
    end

    assert_redirected_to dashboard_bookmarks_url
    assert_match(/One bookmark was removed/, flash[:notice])
    assert_raises(ActiveRecord::RecordNotFound) { bookmark.reload }
  end
end
