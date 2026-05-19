# frozen_string_literal: true

# Rails test env uses :null_store for Rails.cache; Rack::Attack needs a real store.
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.test?

Rack::Attack.throttled_response_retry_after_header = true

module RackAttackThrottles
  module_function

  def normalize_email(req)
    req.params.dig('user', 'email').to_s.downcase.gsub(/\s+/, '')
  end
end

# 1. Login per IP
Rack::Attack.throttle('logins/ip', limit: 20, period: 60) do |req|
  req.ip if req.path == '/user/sign_in' && req.post?
end

# 1. Login per email
Rack::Attack.throttle('logins/email', limit: 10, period: 60) do |req|
  if req.path == '/user/sign_in' && req.post?
    email = RackAttackThrottles.normalize_email(req)
    email if email.present?
  end
end

# 2. Password reset per email
Rack::Attack.throttle('passwords/email', limit: 5, period: 3600) do |req|
  if req.path == '/user/password' && req.post?
    email = RackAttackThrottles.normalize_email(req)
    email if email.present?
  end
end

# 2. Password reset per IP
Rack::Attack.throttle('passwords/ip', limit: 10, period: 3600) do |req|
  req.ip if req.path == '/user/password' && req.post?
end

# 3. Registration per IP
Rack::Attack.throttle('signups/ip', limit: 5, period: 3600) do |req|
  req.ip if req.path == '/user' && req.post?
end

# 4. Admin login per IP
Rack::Attack.throttle('admin logins/ip', limit: 5, period: 300) do |req|
  req.ip if req.path == '/admin/login' && req.post?
end

# 5. Confirmation resend per email
Rack::Attack.throttle('confirmations/email', limit: 5, period: 3600) do |req|
  if req.path == '/user/confirmation' && req.post?
    email = RackAttackThrottles.normalize_email(req)
    email if email.present?
  end
end

# 6. Search per IP
Rack::Attack.throttle('search/ip', limit: 60, period: 60) do |req|
  req.ip if req.path == '/search' && req.get?
end
