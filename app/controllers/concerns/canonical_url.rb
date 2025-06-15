module CanonicalUrl
  extend ActiveSupport::Concern

  def canonical_url(page_out_of_range: false)
    url = "#{ENV.fetch('FULL_HOST', '')}#{request.path}"

    if active_index_filters.any? || params[:page].present?
      filter_params = {}

      if active_index_filters[:sub_category].present?
        filter_params[:category] =
          "#{active_index_filters[:category].slug}[#{active_index_filters[:sub_category].slug}]"
      elsif active_index_filters[:category].present?
        filter_params[:category] = active_index_filters[:category].slug
      end

      active_index_filters.except(:category, :sub_category).each do |filter|
        filter_params[filter[0]] = filter[1]
      end

      filter_params[:page] = params[:page] if params[:page].present? && params[:page].to_i > 1 && !page_out_of_range

      url += "?#{filter_params.to_query}" if filter_params.any?
    end

    url
  end
end
