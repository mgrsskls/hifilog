module FilterConstants
  STATUSES = %w[discontinued continued].freeze
  COUNTRY_CODES = ISO3166::Country.all.map(&:alpha2).freeze
end
