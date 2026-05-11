# frozen_string_literal: true

# Resolves /c/:category_slug(/:sub_category_slug) request params, validates
# parent/child category relationship, and optionally 301-redirects legacy ?category=.
module CategoryPathFromSegments
  extend ActiveSupport::Concern
  include FilterableService

  private

  def category_pair_from_path_segments
    return [nil, nil] if params[:category_slug].blank?

    extract_category_from_path(
      category_slug: params[:category_slug],
      sub_category_slug: params[:sub_category_slug]
    )
  end

  def invalid_category_path_resolution?(category, sub_category)
    return false if params[:category_slug].blank?

    category.nil? ||
      (params[:sub_category_slug].present? && sub_category.nil?) ||
      mismatched_category_sub_category?(category, sub_category)
  end

  def merge_path_unaware_query(passed = params)
    raw = passed.except(:controller, :action, :category, :category_slug, :sub_category_slug, :brand_id, :id)
    permitted = raw.respond_to?(:permit!) ? raw.permit! : raw
    permitted.to_unsafe_h
  end
end
