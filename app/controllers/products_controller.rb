class ProductsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper
  include ApplicationHelper
  include FilterableService
  include FriendlyFinder
  include FilterParamsBuilder

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_breadcrumb, except: [:index]
  before_action :set_active_menu
  before_action :find_product, only: [:show]

  def index
    @category, @sub_category, @custom_attributes = extract_filter_context(allowed_index_filter_params)
    @filter_applied = active_index_filters.except(:category, :sub_category).any?

    filter = ProductFilterService.new(active_index_filters, nil, @category, @sub_category).filter
    @products = filter.products
                      .includes(:brand, :product_variants, sub_categories: [:custom_attributes])
                      .page(params[:page])
    @products_query = params[:query].strip if params[:query].present?

    @page_title = Product.model_name.human(count: 2)

    add_breadcrumb Product.model_name.human(count: 2)
    if @sub_category
      add_breadcrumb @category.name, products_path(category: @category.friendly_id)
      add_breadcrumb @sub_category.name
    elsif @category
      add_breadcrumb @category.name
    end
  end

  def show
    @brand = @product.brand

    if user_signed_in?
      @possessions = current_user.possessions
                                 .includes(:product, :product_option, :setup_possession, :setup)
                                 .where(product_id: @product.id, product_variant_id: nil)
                                 .order([:prev_owned, :period_from, :period_to, :created_at])
                                 .map { |possession| map_possession_to_presenter(possession) }
      @bookmark = current_user.bookmarks.find_by(product_id: @product.id, product_variant_id: nil)
      @note = current_user.notes.find_by(product_id: @product.id, product_variant_id: nil)
      @setups = current_user.setups.includes(:possessions)
    end

    @images = @product.possessions
                      .includes(:images_attachments)
                      .joins(:user)
                      .where(user: { profile_visibility: user_signed_in? ? [1, 2] : 2 })
                      .select { |possession| possession.images.attached? }
                      .map { |possession| PossessionPresenter.new possession }
                      .flat_map(&:sorted_images)
                      .map { |image| ImagePresenter.new(image) }

    @contributors = ActiveRecord::Base.connection.execute("
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = #{@product.id} AND versions.item_type = 'Product'
    ")

    add_breadcrumb @product.display_name
    @page_title = [@product.brand&.name, @product.name].compact.join(' ')
  end

  def new
    @page_title = I18n.t('product.new.heading')

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @product = @sub_category ? Product.new(sub_category_ids: [@sub_category.id]) : Product.new
    @brand = @product.build_brand
    @brands = Brand.order('LOWER(name)')
    @categories = Category.includes([:sub_categories])

    if params[:brand_id].present?
      @product.brand_id = params[:brand_id]
      @brand = Brand.find(params[:brand_id])

      add_breadcrumb @brand.display_name, brand_path(@brand)
    end

    add_breadcrumb t('add_product')
  end

  def edit
    @product = Product.friendly.find(params[:id])
    @page_title = I18n.t('edit_record', name: @product.name)
    @brand = @product.brand
    @categories = Category.includes([:sub_categories])

    add_breadcrumb @product.display_name, product_path(id: @product.friendly_id)
    add_breadcrumb I18n.t('edit')
  end

  def create
    @product = Product.new(product_params)
    brand = assign_brand_from_params(product_params)

    unless brand.save
      if params[:product_options_attributes].present?
        process_product_options(@product,
                                params[:product_options_attributes])
      end
      @categories = Category.includes([:sub_categories])
      @brand = brand
      render :new, status: :unprocessable_entity and return
    end

    @product.brand_id = brand.id
    @product.discontinued = brand.discontinued ? true : product_params[:discontinued]

    if params[:product_options_attributes].present?
      process_product_options(@product,
                              params[:product_options_attributes])
    end

    if @product.save
      redirect_to URI.parse(product_url(id: @product.friendly_id)).path
    else
      @categories = Category.includes([:sub_categories])
      @brand = brand
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @product = Product.find(params[:id])
    old_name = @product.name
    @product.slug = nil if old_name != product_update_params[:name]

    if product_update_params[:custom_attributes].present?
      convert_custom_attributes_to_integer!(product_update_params[:custom_attributes])
    end

    if params[:product_options_attributes].present?
      process_product_options(@product,
                              params[:product_options_attributes])
    end

    if @product.update(product_update_params)
      redirect_to URI.parse(product_url(id: @product.friendly_id)).path
    else
      @categories = Category.includes([:sub_categories])
      @brand = Brand.find(@product.brand_id)
      render :edit, status: :unprocessable_entity
    end
  end

  def changelog
    @product = Product.friendly.find(params[:product_id])
    @brand = @product.brand
    @versions = @product.versions.select do |v|
      log = get_changelog(v.object_changes)
      log.length > 1 || (log.length == 1 && log['slug'].nil?)
    end

    add_breadcrumb @product.display_name, product_path(id: @product.friendly_id)
    add_breadcrumb I18n.t('headings.changelog')
  end

  private

  def find_product
    @product = find_resource(Product, :id, path_helper: ->(p) { product_path(p) })
  end

  def set_active_menu
    @active_menu = :products
  end

  def set_breadcrumb
    add_breadcrumb Product.model_name.human(count: 2), proc { :products }
  end

  def product_params
    if params[:product][:product_options_attributes].present?
      options = {}

      params[:product][:product_options_attributes].each do |i, product_option|
        options[i] = product_option if product_option[:option].present?
      end

      params[:product][:product_options_attributes] = options
    end

    params
      .expect(
        product: [:name,
                  :brand_id,
                  :discontinued,
                  :diy_kit,
                  :release_day,
                  :release_month,
                  :release_year,
                  :discontinued_day,
                  :discontinued_month,
                  :discontinued_year,
                  :description,
                  :price,
                  :price_currency,
                  { custom_attributes: {},
                    sub_category_ids: [],
                    product_options_attributes: {},
                    brand_attributes: [
                      :name,
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
                      :description
                    ] }]
      )
  end

  def product_update_params
    params
      .expect(
        product: [:name,
                  :discontinued,
                  :diy_kit,
                  :release_day,
                  :release_month,
                  :release_year,
                  :discontinued_day,
                  :discontinued_month,
                  :discontinued_year,
                  :description,
                  :price,
                  :price_currency,
                  :comment,
                  { custom_attributes: {},
                    sub_category_ids: [] }],
      )
  end

  def allowed_index_filter_params
    params.permit(:category, :letter, :status, :diy_kit, :country, :query, :sort, attr: {})
  end

  def active_index_filters
    build_filters(allowed_index_filter_params)
  end

  def map_possession_to_presenter(possession)
    if possession.prev_owned
      PreviousPossessionPresenter.new(possession, :product)
    else
      CurrentPossessionPresenter.new(possession, :product)
    end
  end

  def assign_brand_from_params(params)
    if params[:brand_id].present?
      brand = Brand.find(params[:brand_id])
      sub_category_ids = params[:sub_category_ids] || []
      sub_category_ids = sub_category_ids.map(&:to_i)
      missing_sub_ids = sub_category_ids - brand.sub_category_ids
      missing_sub_ids.each do |id|
        sub_category = SubCategory.find(id)
        brand.sub_categories << sub_category if sub_category && brand.sub_categories.exclude?(sub_category)
      end
    else
      brand = Brand.new(params[:brand_attributes])
      (params[:sub_category_ids] || []).each do |id|
        sub_category = SubCategory.find(id.to_i)
        brand.sub_categories << sub_category if sub_category
      end
    end
    brand
  end

  def process_product_options(product, options_attributes)
    options_attributes.each_value do |option|
      if option[:id].present? && option[:option].present?
        product.product_options.find(option[:id]).update(option: option[:option])
      elsif option[:id].present?
        product.product_options.find(option[:id]).delete
      elsif option[:option].present?
        product.product_options << ProductOption.new(option: option[:option])
      end
    end
  end

  def convert_custom_attributes_to_integer!(custom_attributes)
    custom_attributes.each do |key, value|
      custom_attributes[key] = value.to_i
    end
  end
end
