module FilterParamsBuilder
  include FilterConstants
  extend ActiveSupport::Concern

  def build_filters(params_hash)
    filters = {}
    filters[:category] = @category if @category.present?
    filters[:sub_category] = @sub_category if @sub_category.present?

    filters[:status] = params_hash[:status] if params_hash[:status].present? && STATUSES.include?(params_hash[:status])
    filters[:query] = params_hash[:query] if params_hash[:query].present? && !params_hash[:query].strip.empty?
    filters[:sort] = params_hash[:sort] if params_hash[:sort].present?

    filters
  end

  def build_product_filters(params_hash)
    filters = {}

    if params_hash[:products].present?
      if params_hash.dig(:products, :diy_kit).present? && %w[0 1].include?(params_hash.dig(:products, :diy_kit))
        filters[:diy_kit] = params_hash.dig(:products, :diy_kit)
      end

      active_custom_filters = params_hash[:products].except({ products: [:diy_kit] })
      filters[:custom] = params_hash[:products].except if flatten_query_values(active_custom_filters).any?
    end

    filters
  end

  def build_brand_filters(params_hash)
    filters = {}

    if params_hash.dig(:brands, :country) && COUNTRY_CODES.include?(params_hash.dig(:brands, :country).upcase)
      filters[:country] = params_hash[:brands][:country]
    end

    filters
  end

  private

  def flatten_query_values(params)
    result = []

    case params
    when ActionController::Parameters, Hash
      params.each_value do |value|
        result += flatten_query_values(value)
      end
    when Array
      params.each do |value|
        result += flatten_query_values(value)
      end
    else
      result << params.to_s unless params.nil? || params.to_s.blank?
    end

    result
  end

  def deep_except(params, *paths)
    filtered = params.deep_dup

    paths.each do |keys|
      current = filtered
      keys[0..-2].each do |k|
        if (current.respond_to?(:[]) && current[k].is_a?(ActionController::Parameters)) || current[k].is_a?(Hash)
          current = current[k]
        end
      end

      current.delete(keys.last) if current.respond_to?(:delete)
    end

    filtered
  end
end
