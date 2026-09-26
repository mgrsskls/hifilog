# frozen_string_literal: true

require 'test_helper'

class RackAttackThrottleTest < ActionDispatch::IntegrationTest
  # Rails routes accept a format suffix (/user/sign_in.json reaches the same action as
  # /user/sign_in). Requests with a suffix must count toward the same limit, or the suffix is a
  # second path without a limit. Rack::Attack counts before routing, so the series path needs no
  # records. Name => [method, path, limit per IP].
  FORMAT_SUFFIX_CASES = {
    'login' => [:post, '/user/sign_in', 20],
    'admin login' => [:post, '/admin/login', 5],
    'password reset' => [:post, '/user/password', 10],
    'registration' => [:post, '/user', 5],
    'confirmation resend' => [:post, '/user/confirmation', 10],
    'catalog write' => [:post, '/products', 30],
    'series products' => [:get, '/brands/brand/series/series/products', 60],
    'search' => [:get, '/search', 60]
  }.freeze

  FORMAT_SUFFIX_CASES.each_with_index do |(name, (method, path, limit)), index|
    test "a format suffix counts toward the #{name} limit" do
      headers = { 'REMOTE_ADDR' => "192.0.2.#{index + 1}" }

      limit.times do |i|
        send(method, "#{path}#{'.json' if i.odd?}", headers:)
        assert_not_equal 429, response.status, "request #{i + 1} of #{limit}"
      end

      send(method, "#{path}.JSON", headers:)
      assert_response :too_many_requests
    end
  end

  setup do
    Rack::Attack.cache.store.clear
    # Rack::Attack counts in fixed periods (Time.now / period). Without a frozen clock, a test
    # whose requests cross the end of a period starts a new count and does not reach the limit.
    freeze_time
  end

  teardown do
    Rack::Attack.cache.store.clear
  end

  test 'throttles repeated login attempts by IP' do
    20.times do |i|
      post user_session_url,
           params: { user: { email: "ip-throttle-#{i}@example.com", password: 'wrong' } },
           headers: { 'REMOTE_ADDR' => '203.0.113.10' }
      assert_not_equal 429, response.status
    end

    post user_session_url,
         params: { user: { email: 'ip-throttle-last@example.com', password: 'wrong' } },
         headers: { 'REMOTE_ADDR' => '203.0.113.10' }
    assert_response :too_many_requests
    assert response.headers['Retry-After'].present?
  end

  test 'throttles repeated login attempts by email across IPs' do
    params = { user: { email: 'throttle-me@example.com', password: 'wrong' } }

    10.times do |i|
      post user_session_url, params: params, headers: { 'REMOTE_ADDR' => "203.0.113.#{i}" }
      assert_not_equal 429, response.status
    end

    post user_session_url, params: params, headers: { 'REMOTE_ADDR' => '203.0.113.99' }
    assert_response :too_many_requests
  end

  test 'throttles repeated signups by email' do
    params = {
      privacy_policy_accepted: '1',
      user: {
        user_name: 'signup_throttle',
        email: 'signup-throttle@example.com',
        password: 'passwordpassword',
        password_confirmation: 'passwordpassword'
      }
    }

    3.times do |i|
      post user_registration_url, params: params, headers: { 'REMOTE_ADDR' => "198.51.100.#{i}" }
      assert_not_equal 429, response.status
    end

    post user_registration_url, params: params, headers: { 'REMOTE_ADDR' => '198.51.100.99' }
    assert_response :too_many_requests
  end

  test 'throttles repeated confirmation resend requests by IP' do
    10.times do |i|
      post user_confirmation_url,
           params: { user: { email: "confirm-ip-#{i}@example.com" } },
           headers: { 'REMOTE_ADDR' => '203.0.113.10' }
      assert_not_equal 429, response.status
    end

    post user_confirmation_url,
         params: { user: { email: 'confirm-ip-last@example.com' } },
         headers: { 'REMOTE_ADDR' => '203.0.113.10' }
    assert_response :too_many_requests
  end

  test 'throttles repeated password reset requests by email' do
    params = { user: { email: users(:one).email } }

    5.times do |i|
      post user_password_url, params: params, headers: { 'REMOTE_ADDR' => "198.51.100.#{i}" }
      assert_not_equal 429, response.status
    end

    post user_password_url, params: params, headers: { 'REMOTE_ADDR' => '198.51.100.99' }
    assert_response :too_many_requests
  end

  test 'throttles repeated catalog write requests by IP' do
    product = products(:one)
    params = { product: { name: 'catalog throttle product' } }
    headers = { 'REMOTE_ADDR' => '198.51.100.50' }

    30.times do
      post products_url, params: params, headers: headers
      assert_not_equal 429, response.status
    end

    post products_url, params: params, headers: headers
    assert_response :too_many_requests

    headers = { 'REMOTE_ADDR' => '198.51.100.51' }

    patch product_url(product), params: params, headers: headers
    assert_not_equal 429, response.status
  end

  test 'throttles repeated bookmark mutations by IP' do
    product = products(:two)
    headers = { 'REMOTE_ADDR' => '198.51.100.60' }

    120.times do
      post bookmarks_path(product_id: product.id), headers: headers
      assert_not_equal 429, response.status
    end

    post bookmarks_path(product_id: product.id), headers: headers
    assert_response :too_many_requests
  end

  test 'throttles repeated note mutations by IP' do
    product = products(:two)
    params = { note: { text: 'throttle note', product_id: product.id } }
    headers = { 'REMOTE_ADDR' => '198.51.100.70' }

    60.times do
      post notes_url, params: params, headers: headers
      assert_not_equal 429, response.status
    end

    post notes_url, params: params, headers: headers
    assert_response :too_many_requests
  end

  test 'throttles repeated follow mutations by IP' do
    sign_in users(:one)
    followed = users(:logged_in_only)
    headers = { 'REMOTE_ADDR' => '198.51.100.80' }

    60.times do |_i|
      post user_follows_path,
           params: { followed_id: followed.id, redirect_to: dashboard_following_path },
           headers: headers
      assert_not_equal 429, response.status
      follow = UserFollow.find_by(follower: users(:one), followed:)
      follow&.destroy
      UserBlock.where(blocker: users(:one), blocked: followed).destroy_all
    end

    post user_follows_path,
         params: { followed_id: followed.id, redirect_to: dashboard_following_path },
         headers: headers
    assert_response :too_many_requests
  end
end
