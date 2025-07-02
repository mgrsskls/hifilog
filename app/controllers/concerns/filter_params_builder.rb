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

    if params_hash[:diy_kit].present? && %w[0 1].include?(params_hash[:diy_kit])
      filters[:diy_kit] = params_hash[:diy_kit]
    end

    if params_hash[:country].present? && COUNTRY_CODES.include?(params_hash[:country].upcase)
      filters[:country] = params_hash[:country]
    end

    filters[:custom] = params_hash.except(:category, :sub_category, :letter, :status, :query, :sort, :diy_kit, :country)

    filters
  end
end
