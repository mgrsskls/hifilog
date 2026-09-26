# frozen_string_literal: true

# The filter forms send nested params, for example products[query]=x. Crawlers also send
# products=x. The controllers and the filter partial read these params with params.dig, which
# raises a TypeError for a string. This concern removes such values, so the page shows no filter.
# See docs/catalog-listing-and-search.md#6-filters.
module FilterParamsSanitizer
  extend ActiveSupport::Concern

  FILTER_PARAM_KEYS = [:brands, :products].freeze

  included do
    before_action :discard_malformed_filter_params
  end

  private

  def discard_malformed_filter_params
    FILTER_PARAM_KEYS.each do |key|
      params.delete(key) if params.key?(key) && !params[key].is_a?(ActionController::Parameters)
    end
  end
end
