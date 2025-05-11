class BrandsController < ApplicationController
  include ApplicationHelper
  include FilterableService
  include FriendlyFinder
  include FilterParamsBuilder

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_breadcrumb, except: [:index]
  before_action :set_active_menu
  before_action :find_brand, only: [:show]

  def index
    @category, @sub_category, @custom_attributes = extract_filter_context(allowed_index_filter_params)
    @filter_applied = active_index_filters.except(:category, :sub_category).any?

    filter = BrandFilterService.new(active_index_filters, @category, @sub_category).filter
    @brands = filter.brands
                    .includes(sub_categories: [:category])
                    .page(params[:page])

    @product_counts = if active_index_filters.keys.map(&:to_s).any? do |el|
      allowed_index_product_filter_params.to_h.keys.include?(el)
    end
                        ProductFilterService.new(
                          active_index_product_filters,
                          @brands,
                          @category,
                          @sub_category
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

    @page_title = Brand.model_name.human(count: 2)

    add_breadcrumb Brand.model_name.human(count: 2)
    if @sub_category
      add_breadcrumb @category.name, brands_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name
    elsif @category
      add_breadcrumb @category.name
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
    add_breadcrumb @brand.name, brand_path(@brand)
  end

  def products
    @brand = Brand.includes(sub_categories: [:category], products: [:product_variants]).friendly.find(params[:brand_id])
    @category, @sub_category, @custom_attributes = extract_filter_context(allowed_show_product_filter_params)
    @filter_applied = active_show_product_filters.any?
    filter = ProductFilterService.new(active_show_product_filters, [@brand], @category, @sub_category).filter
    @products = filter.products
                      .includes([:sub_categories, :product_variants])
                      .page(params[:page])
    @total_products_count = @brand.products.length
    @all_sub_categories_grouped ||= @brand.sub_categories.group_by(&:category).sort_by { |c| c[0].order }
    @products_query = params[:query].strip if params[:query].present?

    @page_title = @brand.name
    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb Product.model_name.human(count: 2)
  end

  def new
    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @brand = @sub_category ? Brand.new(sub_category_ids: [@sub_category.id]) : Brand.new
    @categories = Category.includes([:sub_categories])

    @page_title = I18n.t('brand.new.heading')
    add_breadcrumb I18n.t('brand.new.heading')
  end

  def edit
    @brand = Brand.friendly.find(params[:id])
    @categories = Category.includes([:sub_categories])

    @page_title = I18n.t('edit_record', name: @brand.name)
    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb I18n.t('edit')
  end

  def create
    @brand = Brand.new(brand_params)

    if @brand.save
      redirect_to brand_path(@brand)
    else
      @categories = Category.includes([:sub_categories])
      render :new, status: :unprocessable_entity
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
      render :edit, status: :unprocessable_entity
    end
  end

  def changelog
    @brand = Brand.friendly.find(params[:brand_id])
    @versions = @brand.versions.select do |v|
      log = get_changelog(v.object_changes)
      log.length > 1 || (log.length == 1 && log['slug'].nil?)
    end

    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb I18n.t('headings.changelog')
  end

  private

  def find_brand
    @brand = find_resource(Brand, :id, path_helper: ->(b) { brand_path(b) })
  end

  def set_active_menu
    @active_menu = :brands
  end

  def set_breadcrumb
    add_breadcrumb Brand.model_name.human(count: 2), proc { :brands }
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
    params.permit(
      :category, :letter, :status, :country, :diy_kit, :query, :sort,
      attr: {}
    )
  end

  def allowed_index_product_filter_params
    params.permit(
      :category, :diy_kit, attr: {}
    )
  end

  def allowed_show_product_filter_params
    params.permit(
      :category, :letter, :status, :diy_kit, :query, :sort, attr: {}
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
