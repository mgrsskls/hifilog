# frozen_string_literal: true

require 'simplecov'
SimpleCov.start
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

module TestSupportHelpers
  ONE_BY_ONE_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ).freeze

  def one_by_one_png_upload(filename: 'test.png')
    { io: StringIO.new(ONE_BY_ONE_PNG), filename:, content_type: 'image/png' }
  end

  def replace_request_env!(url)
    request.env.replace(Rack::MockRequest.env_for(url))
  end

  def with_kaminari_per_page(per_page)
    old_per_page = Kaminari.config.default_per_page
    Kaminari.config.default_per_page = per_page
    yield
  ensure
    Kaminari.config.default_per_page = old_per_page
  end
end

module MailerTestHelper
  def mail_body_html(mail)
    mail.multipart? ? mail.html_part.body.decoded : mail.body.decoded
  end

  def mail_body_text(mail)
    mail.multipart? ? mail.text_part.body.decoded : mail.body.decoded
  end

  def assert_plain_text_email(body)
    assert_no_match(%r{</?[a-z][^>]*>}i, body, 'expected plain text without HTML tags')
  end
end

class ActionMailer::TestCase
  include MailerTestHelper
end

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  # parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  include Devise::Test::IntegrationHelpers
  include TestSupportHelpers
end

# Rack::Attack uses a shared MemoryStore in test; clear it so throttled endpoints
# (sign-up, login, etc.) do not leak counts across unrelated integration tests.
class ActionDispatch::IntegrationTest
  setup { Rack::Attack.cache.store.clear }
  teardown { Rack::Attack.cache.store.clear }
end
