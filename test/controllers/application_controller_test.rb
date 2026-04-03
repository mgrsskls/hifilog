# frozen_string_literal: true

require 'test_helper'

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test 'index for logged out user' do
    get root_url
    assert_response :success
  end

  test 'index for logged in user redirects to dashboard' do
    sign_in users(:one)
    get root_url
    assert_response :redirect
    assert_redirected_to dashboard_root_path
  end

  test 'sitemap' do
    get sitemap_path
    assert_response :success
  end

  test 'sitemap xml renders from cached response body' do
    get sitemap_path(format: :xml)
    assert_response :success
  end
end
