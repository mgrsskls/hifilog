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

  test 'home page records analytics for normal browser HTML responses' do
    capturing_active_analytics_requests do |hits|
      get root_url, headers: { 'User-Agent' => 'Mozilla/5.0 (compatible; TestBrowser/1.0)' }

      assert_response :success
      assert_equal 1, hits.size, 'expected ActiveAnalytics.record_request to run exactly once'
    end
  end

  test 'home page skips analytics for blank user agent' do
    capturing_active_analytics_requests do |hits|
      get root_url, headers: { 'User-Agent' => '' }

      assert_response :success
      assert_empty hits
    end
  end

  test 'home page skips analytics for blocked bot user agents' do
    capturing_active_analytics_requests do |hits|
      get root_url, headers: { 'User-Agent' => 'InternetMeasurement/1.0 crawler' }

      assert_response :success
      assert_empty hits
    end
  end

  test 'home page skips analytics for blocked analytics IP ranges' do
    capturing_active_analytics_requests do |hits|
      get root_url,
          headers: { 'User-Agent' => 'Mozilla/5.0' },
          env: { 'REMOTE_ADDR' => '35.203.210.1' }

      assert_response :success
      assert_empty hits
    end
  end

  test 'unknown product slug renders not found' do
    get product_url(id: 'no-such-product-slug-ever-xyz')
    assert_response :not_found
  end

  private

  def capturing_active_analytics_requests
    recordings = []
    original = ActiveAnalytics.method(:record_request)

    ActiveAnalytics.define_singleton_method(:record_request) do |request|
      recordings << request
    end
    yield recordings
  ensure
    ActiveAnalytics.singleton_class.send(:remove_method, :record_request)
    ActiveAnalytics.singleton_class.define_method(:record_request, original)
  end
end
