# frozen_string_literal: true

require 'test_helper'

class RackAttackThrottleTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store.clear
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

  test 'throttles repeated password reset requests by email' do
    params = { user: { email: users(:one).email } }

    5.times do |i|
      post user_password_url, params: params, headers: { 'REMOTE_ADDR' => "198.51.100.#{i}" }
      assert_not_equal 429, response.status
    end

    post user_password_url, params: params, headers: { 'REMOTE_ADDR' => '198.51.100.99' }
    assert_response :too_many_requests
  end
end
