module FilterParamsBuilder
  include FilterConstants
  extend ActiveSupport::Concern

  def build_filters(params_hash)
    filters = {}
    filters[:category] = @category if @category.present?
    filters[:sub_category] = @sub_category if @sub_category.present?

    filters[:letter] = params_hash[:letter] if params_hash[:letter].present? && ABC.include?(params_hash[:letter])

    filters[:status] = params_hash[:status] if params_hash[:status].present? && STATUSES.include?(params_hash[:status])

    if params_hash[:diy_kit].present? && %w[0 1].include?(params_hash[:diy_kit])
      filters[:diy_kit] = params_hash[:diy_kit]
    end

    if params_hash[:country].present? && COUNTRY_CODES.include?(params_hash[:country].upcase)
      filters[:country] = params_hash[:country]
    end

    filters[:query] = params_hash[:query] if params_hash[:query].present? && !params_hash[:query].strip.empty?

    filters[:attr] = params_hash[:attr] if params_hash[:attr].present?

    filters[:sort] = params_hash[:sort] if params_hash[:sort].present?

    filters
  end
end
