if Rails.env.production?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.traces_sample_rate = 1.0
    config.profiles_sample_rate = 1.0
    config.rails.skippable_job_adapters = ['ActiveAdmin']
  end
end
