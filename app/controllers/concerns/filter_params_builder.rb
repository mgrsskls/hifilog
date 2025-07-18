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

  def build_product_filters(params_hash, nested: false)
    filters = {}

    if nested
      if params_hash[:products].present? && params_hash[:products][:diy_kit].present? && %w[0 1].include?(params_hash[:products][:diy_kit])
        filters[:diy_kit] = params_hash[:products][:diy_kit]
      end
      active_custom_filters = extract_active_keys(deep_except(params_hash, [:products, :diy_kit]))
      filters[:custom] = active_custom_filters[:products] if active_custom_filters.present?
    else
      if params_hash[:diy_kit].present? && %w[0 1].include?(params_hash[:diy_kit])
        filters[:diy_kit] = params_hash[:diy_kit]
      end
      active_custom_filters = extract_active_keys(params_hash.except(:diy_kit))
      filters[:custom] = active_custom_filters if active_custom_filters.present?
    end

    filters
  end

  def build_brand_filters(params_hash, nested: false)
    filters = {}

    if nested
      if params_hash[:brands].present? && params_hash[:brands][:country].present? && COUNTRY_CODES.include?(params_hash[:brands][:country].upcase)
        filters[:country] = params_hash[:brands][:country]
      end
    else
      if params_hash[:country].present? && COUNTRY_CODES.include?(params_hash[:country].upcase)
        filters[:country] = params_hash[:country]
      end
    end

    filters
  end

  private

  def extract_active_keys(param)
    case param
    when Hash
      result = param.each_with_object({}) do |(k, v), h|
        nested = extract_active_keys(v)
        h[k] = nested unless nested.blank?
      end
      result.presence
    else
      param.present? ? param : nil
    end
  end

  def deep_except(params, *paths)
    filtered = params.deep_dup

    paths.each do |keys|
      current = filtered
      keys[0..-2].each do |k|
        current = current[k] if current.respond_to?(:[]) && current[k].is_a?(ActionController::Parameters) || current[k].is_a?(Hash)
      end

      current.delete(keys.last) if current.respond_to?(:delete)
    end

    filtered
  end
end
