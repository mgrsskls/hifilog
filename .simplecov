SimpleCov.start 'rails' do
  enable_coverage :branch

  add_filter %r{^/app/admin/}
  add_filter %r{^/config/}
  add_filter %r{^/test/}

  add_group 'Presenters', 'app/presenters'
  add_group 'Serializers', 'app/serializers'
end
