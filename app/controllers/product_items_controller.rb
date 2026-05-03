# frozen_string_literal: true

class ProductItemsController < ApplicationController
  include FilterableService
  include FriendlyFinder
  include FilterParamsBuilder

  before_action :set_active_menu

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
    products = filter.products
    @products = products.page(page_num)

    # Reset to page 1 if out of range
    @products = products.page(1) if @products.out_of_range?

    @products = ProductItem.preload_list_possession_images(@products)

    @products_query = params[:products][:query].strip if params.dig(:products, :query).present?

    @canonical_url = products_url

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
    @category_data ||= extract_category(params[:category])
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
    allowed = [:category, :sort, :page,
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
