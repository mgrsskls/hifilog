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
end
