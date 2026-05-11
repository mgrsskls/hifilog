# frozen_string_literal: true

require 'simplecov'
SimpleCov.start
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

module TestSupportHelpers
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
