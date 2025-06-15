class ProductsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper
  include ApplicationHelper
  include CanonicalUrl
  include FilterableService
  include FriendlyFinder
  include FilterParamsBuilder

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_active_menu
  before_action :find_product, only: [:show]

  def index
    if params[:sub_category].present?
      sub_category = SubCategory.friendly.find(params[:sub_category])
      category = sub_category.category
      request.query_parameters.delete(:sub_category)
      redirect_to products_path(
        request.query_parameters.merge!(category: "#{category.slug}[#{sub_category.slug}]")
      ), status: :moved_permanently
    end

    @category, @sub_category, @custom_attributes = extract_filter_context(allowed_index_filter_params)
    @filter_applied = active_index_filters.except(:category, :sub_category).any?

    filter = ProductFilterService.new(active_index_filters, [], @category, @sub_category).filter
    @products = filter.products
                      .includes(:brand, :product_variants, sub_categories: [:custom_attributes])
                      .page(params[:page])
    @products_query = params[:query].strip if params[:query].present?

    if @products.out_of_range?
      @products = filter.products
                        .includes(:brand, :product_variants, sub_categories: [:custom_attributes])
                        .page(1)
      @canonical_url = canonical_url(page_out_of_range: true)
    else
      @canonical_url = canonical_url
    end

    if @sub_category.present?
      @page_title = @sub_category.name
      @meta_desc = "Search through all products in the category “#{@sub_category.name}” on HiFi Log,\
 a user-driven database for HiFi products and brands."
    elsif @category.present?
      @page_title = @category.name
      @meta_desc = "Search through all products in the category “#{@category.name}” on HiFi Log,\
 a user-driven database for HiFi products and brands."
    else
      @page_title = Product.model_name.human(count: 2)
      @meta_desc = 'Search through all products on HiFi Log, a user-driven database for HiFi products and brands.'
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

    @page_title = [@product.brand&.name, @product.name].compact.join(' ')
  end

  def new
    @page_title = I18n.t('product.new.heading')

    @sub_category = SubCategory.friendly.find(params[:sub_category]) if params[:sub_category].present?
    @product = @sub_category ? Product.new(sub_category_ids: [@sub_category.id]) : Product.new
    @brand = @product.build_brand
    @brands = Brand.order('LOWER(name)')
    @categories = Category.includes([:sub_categories])

    return if params[:brand_id].blank?

    @product.brand_id = params[:brand_id]
    @brand = Brand.find(params[:brand_id])
  end

  def edit
    @product = Product.friendly.find(params[:id])
    @page_title = I18n.t('edit_record', name: @product.name)
    @brand = @product.brand
    @categories = Category.includes([:sub_categories])
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
  end

  private

  def find_product
    @product = find_resource(Product, :id, path_helper: ->(p) { product_path(p) })
  end

  def set_active_menu
    @active_menu = :products
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
      Brand.find(params[:brand_id])
    else
      Brand.new(params[:brand_attributes])
    end
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
