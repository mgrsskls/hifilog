# frozen_string_literal: true

# Rails test env uses :null_store for Rails.cache; Rack::Attack needs a real store.
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.test?

Rack::Attack.throttled_response_retry_after_header = true

module RackAttackThrottles
  CATALOG_WRITE_PATH = %r{\A/(products|brands)(/|$)}.freeze
  SERIES_PRODUCTS_PATH = %r{\A/brands/[^/]+/series/[^/]+/products\z}.freeze
  # The (.:format) segment of a Rails route: a dot and then no slash or dot up to the end.
  FORMAT_SUFFIX = %r{\.[^/.]+\z}

  module_function

  # The path without a format suffix. Rails routes /user/sign_in.json to the same action as
  # /user/sign_in, so every throttle compares this path. Otherwise a suffix is a second path to the
  # action without a limit (docs/privacy-auth-security.md#3-security).
  def path(req)
    req.path.sub(FORMAT_SUFFIX, '')
  end

  def normalize_email(req)
    req.params.dig('user', 'email').to_s.downcase.gsub(/\s+/, '')
  end

  def write_request?(req)
    %w[POST PATCH PUT].include?(req.request_method)
  end
end

# 1. Login per IP
Rack::Attack.throttle('logins/ip', limit: 20, period: 60) do |req|
  req.ip if RackAttackThrottles.path(req) == '/user/sign_in' && req.post?
end

# 1. Login per email
Rack::Attack.throttle('logins/email', limit: 10, period: 60) do |req|
  if RackAttackThrottles.path(req) == '/user/sign_in' && req.post?
    email = RackAttackThrottles.normalize_email(req)
    email if email.present?
  end
end

# 2. Password reset per email
Rack::Attack.throttle('passwords/email', limit: 5, period: 3600) do |req|
  if RackAttackThrottles.path(req) == '/user/password' && req.post?
    email = RackAttackThrottles.normalize_email(req)
    email if email.present?
  end
end

# 2. Password reset per IP
Rack::Attack.throttle('passwords/ip', limit: 10, period: 3600) do |req|
  req.ip if RackAttackThrottles.path(req) == '/user/password' && req.post?
end

# 3. Registration per IP
Rack::Attack.throttle('signups/ip', limit: 5, period: 3600) do |req|
  req.ip if RackAttackThrottles.path(req) == '/user' && req.post?
end

# 3b. Registration per email
Rack::Attack.throttle('signups/email', limit: 3, period: 3600) do |req|
  if RackAttackThrottles.path(req) == '/user' && req.post?
    email = RackAttackThrottles.normalize_email(req)
    email if email.present?
  end
end

# 4. Admin login per IP
Rack::Attack.throttle('admin logins/ip', limit: 5, period: 300) do |req|
  req.ip if RackAttackThrottles.path(req) == '/admin/login' && req.post?
end

# 5. Confirmation resend per email
Rack::Attack.throttle('confirmations/email', limit: 5, period: 3600) do |req|
  if RackAttackThrottles.path(req) == '/user/confirmation' && req.post?
    email = RackAttackThrottles.normalize_email(req)
    email if email.present?
  end
end

# 5b. Confirmation resend per IP
Rack::Attack.throttle('confirmations/ip', limit: 10, period: 3600) do |req|
  req.ip if RackAttackThrottles.path(req) == '/user/confirmation' && req.post?
end

# 7. Catalog writes per IP (wiki product/brand create and update)
Rack::Attack.throttle('catalog_writes/ip', limit: 30, period: 3600) do |req|
  if RackAttackThrottles.write_request?(req) &&
     RackAttackThrottles.path(req).match?(RackAttackThrottles::CATALOG_WRITE_PATH)
    req.ip
  end
end

# 8. Bookmark mutations per IP
Rack::Attack.throttle('bookmarks/ip', limit: 120, period: 3600) do |req|
  req.ip if RackAttackThrottles.path(req).start_with?('/bookmarks') && RackAttackThrottles.write_request?(req)
end

# 9. Note mutations per IP
Rack::Attack.throttle('notes/ip', limit: 60, period: 3600) do |req|
  req.ip if RackAttackThrottles.path(req).start_with?('/notes') && RackAttackThrottles.write_request?(req)
end

# 10. Follow and block mutations per IP
Rack::Attack.throttle('follow_mutations/ip', limit: 60, period: 3600) do |req|
  if RackAttackThrottles.write_request?(req) &&
     RackAttackThrottles.path(req).start_with?('/user_follows', '/user_blocks', '/brand_follows')
    req.ip
  end
end

# 11. Product list of the picker dialog of a product series per IP (a GET for signed-in users)
Rack::Attack.throttle('series_products/ip', limit: 60, period: 60) do |req|
  req.ip if req.get? && RackAttackThrottles.path(req).match?(RackAttackThrottles::SERIES_PRODUCTS_PATH)
end

# 6. Search per IP
Rack::Attack.throttle('search/ip', limit: 60, period: 60) do |req|
  req.ip if RackAttackThrottles.path(req) == '/search' && req.get?
end
