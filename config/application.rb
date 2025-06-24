require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)


module HiFiLog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    config.middleware.use Rack::CrawlerDetect
    config.middleware.use Rack::Deflater

    config.active_record.yaml_column_permitted_classes = [
      BigDecimal,
      Symbol,
      Date,
      Time,
      ActiveSupport::TimeWithZone,
      ActiveSupport::TimeZone
    ]

    config.force_ssl = Rails.env.production?

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.after_initialize do
      ActiveAnalytics::ApplicationController.class_eval do
        content_security_policy do |policy|
          policy.base_uri    :self
          policy.default_src :self
          policy.font_src    :none
          policy.img_src     :self, 'https://icons.duckduckgo.com'
          policy.object_src  :none
          policy.script_src  :self
          policy.style_src   :self, :unsafe_inline
        end
      end
    end
  end
end
