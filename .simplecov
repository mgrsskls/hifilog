# frozen_string_literal: true

SimpleCov.load_profile 'rails'

SimpleCov.configure do
  enable_coverage :branch

  skip %r{^/app/admin/}
  skip %r{^/config/}
  skip %r{^/test/}

  group 'Presenters', 'app/presenters'
  group 'Serializers', 'app/serializers'
end
