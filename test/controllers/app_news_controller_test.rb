# frozen_string_literal: true

require 'test_helper'

class AppNewsControllerTest < ActionDispatch::IntegrationTest
  test 'mark_as_read' do
    post app_news_mark_as_read_url(ids: [app_news(:one).id, app_news(:two).id])
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:without_anything)

    assert_equal users(:without_anything).app_news_ids, []

    post app_news_mark_as_read_url(ids: [app_news(:one).id, app_news(:two).id])

    assert_equal users(:without_anything).app_news, [app_news(:one), app_news(:two)]
    assert_response :redirect
    assert_redirected_to dashboard_root_path
  end

  test 'mark_as_read without ids marks nothing and redirects' do
    sign_in users(:without_anything)

    post app_news_mark_as_read_url

    assert_redirected_to dashboard_root_path
    assert_empty users(:without_anything).reload.app_news
  end

  test 'mark_as_read with one id instead of a list marks nothing and redirects' do
    sign_in users(:without_anything)

    post app_news_mark_as_read_url, params: { ids: app_news(:one).id }

    assert_redirected_to dashboard_root_path
    assert_empty users(:without_anything).reload.app_news
  end

  test 'mark_as_read skips news that is read already' do
    user = users(:without_anything)
    user.app_news << app_news(:one)
    sign_in user

    post app_news_mark_as_read_url(ids: [app_news(:one).id, app_news(:two).id])

    assert_redirected_to dashboard_root_path
    assert_equal [app_news(:one), app_news(:two)], user.reload.app_news.order(:id).to_a
  end
end
