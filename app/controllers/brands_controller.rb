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
    if params[:sub_category].present?
      sub_category = SubCategory.friendly.find(params[:sub_category])
      category = sub_category.category
      request.query_parameters.delete(:sub_category)
      redirect_to brands_path(
        request.query_parameters.merge!(category: "#{category.slug}[#{sub_category.slug}]")
      ), status: :moved_permanently
    end

    @category, @sub_category, @custom_attributes = extract_filter_context(allowed_index_filter_params)
    @filter_applied = active_index_filters.except(:category, :sub_category).any?

    filter = BrandFilterService.new(filters: active_index_filters, category: @category, sub_category: @sub_category, product_filters:  active_index_product_filters).filter
    @brands = filter.brands
                    .includes(sub_categories: [:category])
                    .page(params[:page])

    if @brands.out_of_range?
      @brands = filter.brands
                      .includes(sub_categories: [:category])
                      .page(1)
    end
    @canonical_url = brands_url

    @product_counts = if active_index_filters.keys.map(&:to_s).any? do |el|
      allowed_index_product_filter_params.to_h.keys.include?(el)
    end
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

    @brands_query = params[:query].strip if params[:query].present?

    if @sub_category.present?
      @page_title = "#{Brand.model_name.human(count: 2)}: #{@sub_category.name}"
      @meta_desc = "Search through all brands with products in the category “#{@sub_category.name}” on HiFi Log,\
 a user-driven database for hi-fi products and brands."
    elsif @category.present?
      @page_title = "#{Brand.model_name.human(count: 2)}: #{@category.name}"
      @meta_desc = "Search through all brands with products in the category “#{@category.name}” on HiFi Log,\
 a user-driven database for hi-fi products and brands."
    else
      @page_title = Brand.model_name.human(count: 2)
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
    @contributors = User.find_by_sql(["
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = ? AND versions.item_type = 'Brand'
    ", @brand.id])
    @all_sub_categories_grouped ||= @brand.sub_categories.group_by(&:category).sort_by { |category| category[0].order }

    @page_title = @brand.name
    set_meta_desc
  end

  def products
    @brand = Brand.includes(sub_categories: [:category], products: [:product_variants]).friendly.find(params[:brand_id])
    @category, @sub_category, @custom_attributes = extract_filter_context(allowed_show_product_filter_params)
    @filter_applied = active_show_product_filters.any?

    filter = ProductFilterService.new(active_show_product_filters, [@brand], @category, @sub_category).filter
    @products = filter.products
                      .page(params[:page])
    if @products.out_of_range?
      @products = filter.products
                        .page(1)
    end
    @canonical_url = brand_products_url(brand_id: @brand.friendly_id)
    @custom_attributes_for_products = CustomAttribute.all
    @product_presenters = @products.map { |p| ProductItemPresenter.new(p) }
    @total_products_count = @brand.products.length
    @all_sub_categories_grouped ||= @brand.sub_categories.group_by(&:category).sort_by { |c| c[0].order }
    @products_query = params[:query].strip if params[:query].present?

    @page_title = @brand.name
    set_meta_desc
  end

  def new
    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @brand = @sub_category ? Brand.new(sub_category_ids: [@sub_category.id]) : Brand.new
    @categories = Category.includes([:sub_categories])

    @page_title = I18n.t('brand.new.heading')
  end

  def edit
    @brand = Brand.friendly.find(params[:id])
    @categories = Category.includes([:sub_categories])

    @page_title = I18n.t('edit_record', name: @brand.name)
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
    @versions = @brand.versions.select do |v|
      log = get_changelog(v.object_changes)
      log.length > 1 || (log.length == 1 && log['slug'].nil?)
    end
  end

  private

  def set_meta_desc
    return if @brand.formatted_description.blank?

    @meta_desc = ActionController::Base.helpers.truncate(
      ActionController::Base.helpers.strip_tags(@brand.formatted_description),
      length: 200, escape: false
    )
  end

  def find_brand
    @brand = find_resource(Brand, :id, path_helper: ->(b) { brand_path(b) })
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
              { sub_category_ids: [] }],
    )
  end

  def allowed_index_filter_params
    params.permit(:category, :status, :country, :diy_kit, :query, :sort)
  end

  def allowed_index_product_filter_params
    custom_attributes = SubCategory.find(11).custom_attributes
    custom_attributes_hash = custom_attributes.map do |custom_attribute|
      {
        custom_attribute[:label] => []
      }
    end

    allowed = [:diy_kit, *custom_attributes_hash]
    params.permit({ products: allowed })
  end

  def allowed_show_product_filter_params
    params.permit(
      :category, :status, :diy_kit, :query, :sort, attr: {}
    )
  end

  def active_index_filters
    build_filters(allowed_index_filter_params)
  end

  def active_index_product_filters
    build_filters(allowed_index_product_filter_params)
  end

  def active_show_product_filters
    build_filters(allowed_show_product_filter_params)
  end
end
