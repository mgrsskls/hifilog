Sentry.init do |config|
  config.dsn = 'https://21e83dc22ecca6f76d65bfac64d5d7be@o4506621346512896.ingest.sentry.io/4506621346643968'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # To activate performance monitoring, set one of these options.
  # We recommend adjusting the value in production:
  config.traces_sample_rate = 1.0
  # or
  config.traces_sampler = lambda do |context|
    true
  end
end
