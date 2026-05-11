# frozen_string_literal: true

class BrandsController < ApplicationController
  include ApplicationHelper
  include FilterableService
  include FriendlyFinder
  include FilterParamsBuilder
  include CategoryPathFromSegments

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_noindex_meta_robots, only: [:new, :edit, :create, :update, :changelog]
  before_action :set_active_menu
  before_action :find_brand, only: [:show]
  before_action :redirect_legacy_category_query_to_brands_path, only: [:index]
  before_action :ensure_brands_index_category_path!, only: [:index]
  before_action :load_brand_for_products_page, only: [:products]
  before_action :redirect_legacy_brand_products_category_query, only: [:products]
  before_action :ensure_brand_products_category_path!, only: [:products]

  def index
    @custom_attributes = extract_custom_attributes(@category, @sub_category)
    @filter_applied = active_index_filters.except(:category, :sub_category).merge(
      active_index_product_filters
    )
    @meta_robots = 'noindex, follow' if @filter_applied.except(:category, :sub_category).present?

    filter = BrandFilterService.new(
      filters: active_index_filters,
      category: @category,
      sub_category: @sub_category,
      product_filters: active_index_product_filters
    ).filter

    brands = filter.brands.with_attached_logo

    @brands = brands.page(params[:page])
    @brands = brands.page(1) if @brands.out_of_range?

    @canonical_url = brands_index_canonical_url

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
      page_title("#{name} — #{heading}")
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
    @brand = Brand.with_attached_logo.includes(sub_categories: [:category]).friendly.find(params[:id])
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
    # @brand from load_brand_for_products_page; @category, @sub_category from ensure_brand_products_category_path!
    @custom_attributes = extract_custom_attributes(@category, @sub_category)
    @filter_applied = active_show_product_filters
    @meta_robots = 'noindex, follow' if @filter_applied.except(:category, :sub_category).present?

    filter = ProductFilterService.new(
      filters: active_show_product_filters,
      brands: [@brand],
      category: @category,
      sub_category: @sub_category
    ).filter

    products = filter.products.includes(:brand)

    @products = products.page(params[:page])
    @products = products.page(1) if @products.out_of_range?

    @products = ProductItem.preload_list_possession_images(@products)

    @canonical_url = brand_products_index_canonical_url
    @total_products_count = @brand.products.length
    @all_sub_categories_grouped ||= @brand.sub_categories.group_by(&:category).sort_by { |category| category[0].order }
    @products_query = params[:products][:query].strip if params.dig(:products, :query).present?

    page_title("#{@brand.name} #{@sub_category&.name || Product.model_name.human.pluralize}")
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

  def set_noindex_meta_robots
    @meta_robots = 'noindex, follow'
  end

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
    params.permit(:sort, brands: [:status, :country, :query])
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
    params.permit(:sort)
  end

  def active_show_product_filters
    build_filters(allowed_show_product_filter_params).merge(
      build_product_filters(allowed_index_product_filter_params)
    )
  end

  def redirect_legacy_category_query_to_brands_path
    return unless request.get?
    return if params[:category_slug].present?

    legacy = params[:category].to_s.presence
    return if legacy.blank?

    cat, sub = extract_category(legacy)
    return if cat.nil?

    extra = merge_path_unaware_query
    target =
      if sub.present?
        brands_subcategory_path(sub.category.friendly_id, sub.friendly_id, **extra)
      else
        brands_category_path(cat.friendly_id, **extra)
      end
    redirect_to target, status: :moved_permanently
  end

  def ensure_brands_index_category_path!
    pair = category_pair_from_path_segments
    return head :not_found if invalid_category_path_resolution?(*pair)

    @category, @sub_category = pair
  end

  def brands_index_canonical_url
    opts = @brands.current_page > 1 ? { page: @brands.current_page } : {}
    if @sub_category.present?
      brands_subcategory_url(
        @sub_category.category.friendly_id,
        @sub_category.friendly_id,
        **opts
      )
    elsif @category.present?
      brands_category_url(@category.friendly_id, **opts)
    else
      brands_url(**opts)
    end
  end

  def load_brand_for_products_page
    @brand = Brand.with_attached_logo.includes(sub_categories: [:category],
                                               products: [:product_variants]).friendly.find(params[:brand_id])
  end

  def redirect_legacy_brand_products_category_query
    return unless request.get?
    return if params[:category_slug].present?

    legacy = params[:category].to_s.presence
    return if legacy.blank?

    cat, sub = extract_category(legacy)
    return if cat.nil?

    extra = merge_path_unaware_query
    target =
      if sub.present?
        brand_brand_products_subcategory_path(
          @brand,
          sub.category.friendly_id,
          sub.friendly_id,
          **extra
        )
      else
        brand_brand_products_category_path(@brand, cat.friendly_id, **extra)
      end
    redirect_to target, status: :moved_permanently
  end

  def ensure_brand_products_category_path!
    pair = category_pair_from_path_segments
    return head :not_found if invalid_category_path_resolution?(*pair)

    @category, @sub_category = pair
  end

  def brand_products_index_canonical_url
    opts = @products.current_page > 1 ? { page: @products.current_page } : {}
    if @sub_category.present?
      brand_brand_products_subcategory_url(
        @brand,
        @sub_category.category.friendly_id,
        @sub_category.friendly_id,
        **opts
      )
    elsif @category.present?
      brand_brand_products_category_url(@brand, @category.friendly_id, **opts)
    else
      brand_products_url({ brand_id: @brand.friendly_id }.merge(opts))
    end
  end
end
