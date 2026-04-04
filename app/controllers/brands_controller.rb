# frozen_string_literal: true

class BrandsController < ApplicationController
  include ApplicationHelper
  include FilterableService
  include FriendlyFinder
  include FilterParamsBuilder

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_active_menu
  before_action :find_brand, only: [:show]

  def index
    @category, @sub_category = extract_category(params[:category])
    @custom_attributes = extract_custom_attributes(@category, @sub_category)
    @filter_applied = active_index_filters.except(:category, :sub_category).merge(
      active_index_product_filters
    )

    filter = BrandFilterService.new(
      filters: active_index_filters,
      category: @category,
      sub_category: @sub_category,
      product_filters: active_index_product_filters
    ).filter

    brands = filter.brands

    @brands = brands.page(params[:page])
    @brands = brands.page(1) if @brands.out_of_range?

    @canonical_url = brands_url

    @product_counts = if active_index_filters.any?
                        ProductFilterService.new(
                          filters: active_index_product_filters,
                          brands: @brands,
                          category: @category,
                          sub_category: @sub_category
                        ).filter.products.group_by(&:brand_id).transform_values(&:length)
                      else
                        @brands.to_h do |brand|
                          [
                            brand.id,
                            brand.products_count
                          ]
                        end
                      end

    @brands_query = params.dig(:brands, :query)&.strip

    heading = Brand.model_name.human.pluralize
    cat = @sub_category.presence || @category.presence

    if cat
      name = cat.name
      page_title("#{heading}: #{name}")
      @meta_desc = "Search through all brands with products in the category “#{name}” on HiFi Log,\
a user-driven database for hi-fi products and brands."
    else
      page_title(heading)
      @meta_desc = 'Search through all brands on HiFi Log, a user-driven database for hi-fi products and brands.'
    end
  end

  def all
    respond_to do |format|
      format.json { render json: { brands: Brand.select([:name, :id]).order('LOWER(name)') } }
    end
  end

  def show
    @brand = Brand.includes(sub_categories: [:category]).friendly.find(params[:id])
    brand_id = @brand.id

    @contributors = User.find_by_sql(["
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = ? AND versions.item_type = 'Brand'
    ", brand_id])
    @all_sub_categories_grouped ||= @brand.sub_categories.group_by(&:category).sort_by { |category| category[0].order }
    @bookmark = current_user.bookmarks.find_by(item_id: brand_id, item_type: 'Brand') if user_signed_in?

    page_title(@brand.name)
    set_meta_desc
  end

  def products
    @brand = Brand.includes(sub_categories: [:category], products: [:product_variants]).friendly.find(params[:brand_id])
    @category, @sub_category = extract_category(params[:category])
    @custom_attributes = extract_custom_attributes(@category, @sub_category)
    @filter_applied = active_show_product_filters

    filter = ProductFilterService.new(
      filters: active_show_product_filters,
      brands: [@brand],
      category: @category,
      sub_category: @sub_category
    ).filter

    products = filter.products

    @products = products.page(params[:page])
    @products = products.page(1) if @products.out_of_range?

    @canonical_url = brand_products_url(brand_id: @brand.friendly_id)
    @total_products_count = @brand.products.length
    @all_sub_categories_grouped ||= @brand.sub_categories.group_by(&:category).sort_by { |category| category[0].order }
    @products_query = params[:products][:query].strip if params.dig(:products, :query).present?

    page_title(@brand.name)
    set_meta_desc
  end

  def new
    sub_category = params[:sub_category]
    @sub_category = SubCategory.friendly.find(sub_category) if sub_category.present?
    @brand = @sub_category ? Brand.new(sub_category_ids: [@sub_category.id]) : Brand.new
    @categories = Category.includes([:sub_categories])

    page_title(I18n.t('brand.new.heading'))
  end

  def edit
    @brand = Brand.friendly.find(params[:id])
    @categories = Category.includes([:sub_categories])

    page_title(I18n.t('edit_record', name: @brand.name))
  end

  def create
    @brand = Brand.new(brand_params)

    if @brand.save
      redirect_to brand_path(@brand)
    else
      @categories = Category.includes([:sub_categories])
      render :new, status: :unprocessable_content
    end
  end

  def update
    @brand = Brand.friendly.find(params[:id])
    is_discontinued = @brand.discontinued

    old_name = @brand.name
    @brand.slug = nil if old_name != brand_params[:name]

    if @brand.update(brand_params)
      if is_discontinued == false && @brand.discontinued == true
        @brand.products.each do |product|
          product.update(discontinued: true)
        end
      end

      redirect_to brand_path(@brand)
    else
      @categories = Category.includes([:sub_categories])
      render :edit, status: :unprocessable_content
    end
  end

  def changelog
    @brand = Brand.friendly.find(params[:brand_id])
    @versions = filter_versions(@brand.versions)
  end

  private

  def set_meta_desc
    desc = @brand.formatted_description

    if desc.present?
      @meta_desc = ActionController::Base.helpers.truncate(
        ActionController::Base.helpers.strip_tags(desc),
        length: 200, escape: false
      )
      return
    end

    @meta_desc = "#{@brand.name} is an audio hi-fi brand. \
    Find out more about it on hifilog.com, a user-driven database for hi-fi products and brands."
  end

  def find_brand
    @brand = find_resource(Brand, :id, path_helper: ->(brand) { brand_path(brand) })
  end

  def set_active_menu
    @active_menu = :brands
  end

  def brand_params
    params.expect(
      brand: [:name,
              :discontinued,
              :full_name,
              :website,
              :country_code,
              :founded_day,
              :founded_month,
              :founded_year,
              :discontinued_day,
              :discontinued_month,
              :discontinued_year,
              :description,
              :comment,
              { sub_category_ids: [] }]
    )
  end

  def allowed_index_filter_params
    params.permit(:category, :sort, brands: [:status, :country, :query])
  end

  def active_index_filters
    build_filters(allowed_index_filter_params).merge(
      build_brand_filters(allowed_index_filter_params.except(:category))
    )
  end

  def allowed_index_product_filter_params
    custom_attributes_hash = *build_custom_attributes_hash(@custom_attributes)
    allowed = [{ products: [:diy_kit, :status, :query, *custom_attributes_hash] }]
    params.permit(allowed)
  end

  def active_index_product_filters
    build_product_filters(allowed_index_product_filter_params)
  end

  def allowed_show_product_filter_params
    params.permit(:category, :sort)
  end

  def active_show_product_filters
    build_filters(allowed_show_product_filter_params).merge(
      build_product_filters(allowed_index_product_filter_params)
    )
  end
end
