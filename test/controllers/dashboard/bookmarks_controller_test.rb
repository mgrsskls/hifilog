# frozen_string_literal: true

require 'test_helper'

class Dashboard::BookmarksControllerTest < ActionDispatch::IntegrationTest
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
end
