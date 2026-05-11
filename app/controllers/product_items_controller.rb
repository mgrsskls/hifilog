# frozen_string_literal: true

class ProductItemsController < ApplicationController
  include FilterableService
  include FriendlyFinder
  include FilterParamsBuilder
  include CategoryPathFromSegments

  before_action :set_active_menu
  before_action :redirect_legacy_category_query_to_product_path, only: [:index]
  before_action :ensure_product_index_category_path!, only: [:index]

  helper_method :current_category, :current_sub_category

  def index
    @category = current_category
    @sub_category = current_sub_category
    @custom_attributes = index_custom_attributes
    @filter_applied = active_index_filters.except(:category, :sub_category).merge(active_index_brand_filters)

    filter = ProductFilterService.new(
      filters: active_index_filters,
      category: current_category,
      sub_category: current_sub_category,
      brand_filters: active_index_brand_filters
    ).filter

    page_num = params[:page].presence || 1
    products = filter.products.includes(:brand)
    @products = products.page(page_num)

    # Reset to page 1 if out of range
    @products = products.page(1) if @products.out_of_range?

    @products = ProductItem.preload_list_possession_images(@products)

    @products_query = params[:products][:query].strip if params.dig(:products, :query).present?

    @canonical_url = products_index_canonical_url

    if current_sub_category.present?
      sub_category_name = current_sub_category.name
      page_title(sub_category_name, "Search through all products in the category “#{sub_category_name}” on HiFi Log,\
    a user-driven database for hi-fi products and brands.")
    elsif current_category.present?
      category_name = current_category.name
      page_title(category_name, "Search through all products in the category “#{category_name}” on HiFi Log,\
    a user-driven database for hi-fi products and brands.")
    else
      page_title(Product.model_name.human.pluralize,
                 'Search through all products on HiFi Log, a user-driven database for hi-fi products and brands.')
    end
  end

  private

  def set_active_menu
    @active_menu = :products
  end

  def category_data
    @category_data ||= category_pair_from_path_segments
  end

  def redirect_legacy_category_query_to_product_path
    return unless request.get?
    return if params[:category_slug].present?

    legacy = params[:category].to_s.presence
    return if legacy.blank?

    cat, sub = extract_category(legacy)
    return if cat.nil?

    extra = merge_path_unaware_query
    target =
      if sub.present?
        products_subcategory_path(sub.category.friendly_id, sub.friendly_id, **extra)
      else
        products_category_path(cat.friendly_id, **extra)
      end
    redirect_to target, status: :moved_permanently
  end

  def ensure_product_index_category_path!
    pair = category_pair_from_path_segments
    return head :not_found if invalid_category_path_resolution?(*pair)

    @category, @sub_category = pair
  end

  def products_index_canonical_url
    opts = @products.current_page > 1 ? { page: @products.current_page } : {}
    if current_sub_category.present?
      products_subcategory_url(
        current_sub_category.category.friendly_id,
        current_sub_category.friendly_id,
        **opts
      )
    elsif current_category.present?
      products_category_url(current_category.friendly_id, **opts)
    else
      products_url(**opts)
    end
  end

  def current_category
    category_data.first
  end

  def current_sub_category
    category_data.last
  end

  def index_custom_attributes
    @index_custom_attributes ||= extract_custom_attributes(current_category, current_sub_category)
  end

  def allowed_index_filter_params
    allowed = [:sort, :page,
               { products: [:status, :query, :diy_kit, *build_custom_attributes_hash(index_custom_attributes)] }]
    params.permit(allowed)
  end

  def active_index_filters
    build_filters(allowed_index_filter_params).merge(
      build_product_filters(allowed_index_filter_params.except(:category, :sort))
    )
  end

  def allowed_index_brand_filter_params
    params.permit({ brands: [:status, :country] })
  end

  def active_index_brand_filters
    build_brand_filters(allowed_index_brand_filter_params)
  end
end
