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

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  # parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  include Devise::Test::IntegrationHelpers
  include TestSupportHelpers
end
