# frozen_string_literal: true

class ProductsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper
  include FriendlyFinder
  include ProductCatalogShow
  include ProductOptionsAssignable

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update]
  before_action :set_noindex_meta_robots, only: [:new, :edit, :create, :update, :changelog]
  before_action :set_active_menu
  before_action :find_product, only: [:show]

  def show
    assign_product_catalog_show_data(product: @product)

    page_title([@product.brand&.name, @product.name].compact.join(' '), @product.meta_desc)
  end

  def new
    page_title(I18n.t('product.new.heading'))

    sub_category = params[:sub_category]
    @sub_category = SubCategory.friendly.find(sub_category) if sub_category.present?
    @product = @sub_category ? Product.new(sub_category_ids: [@sub_category.id]) : Product.new
    @brand = @product.build_brand
    @brands = Brand.order('LOWER(name)')
    @categories = Category.includes([:sub_categories])

    brand_id = params[:brand_id]

    return if brand_id.blank?

    @product.brand_id = brand_id
    @brand = Brand.find(brand_id)
  end

  def edit
    @product = Product.friendly.find(params[:id])
    page_title(I18n.t('edit_record', name: @product.name))
    @brand = @product.brand
    @categories = Category.includes([:sub_categories])
  end

  def create
    @product = Product.new(product_params)
    brand = assign_brand_from_params(product_params)

    product_options_attributes = params[:product_options_attributes]

    unless brand.save
      assign_product_options(@product, product_options_attributes) if product_options_attributes.present?
      @categories = Category.includes([:sub_categories])
      @brand = brand
      render :new, status: :unprocessable_content and return
    end

    @product.brand_id = brand.id
    @product.discontinued = brand.discontinued ? true : product_params[:discontinued]

    assign_product_options(@product, product_options_attributes) if product_options_attributes.present?

    if @product.save
      redirect_to URI.parse(product_url(id: @product.friendly_id)).path
    else
      @categories = Category.includes([:sub_categories])
      @brand = brand
      render :new, status: :unprocessable_content
    end
  end

  def update
    @product = Product.find(params[:id])

    product_options_attributes = params[:product_options_attributes]
    assign_product_options(@product, product_options_attributes) if product_options_attributes.present?

    if @product.update(product_update_params)
      redirect_to URI.parse(product_url(id: @product.friendly_id)).path
    else
      @categories = Category.includes([:sub_categories])
      @brand = Brand.find(@product.brand_id)
      render :edit, status: :unprocessable_content
    end
  end

  def changelog
    @product = Product.friendly.find(params[:product_id])
    @versions = filter_versions(@product.versions)
  end

  private

  def set_noindex_meta_robots
    @meta_robots = 'noindex, follow'
  end

  def find_product
    @product = find_resource(
      Product.includes(:brand, :sub_categories), :id, path_helper: ->(product) { product_path(product) }
    )
  end

  def set_active_menu
    @active_menu = :products
  end

  def product_params
    product_options_attributes = params[:product][:product_options_attributes]

    if product_options_attributes.present?
      options = {}

      product_options_attributes.each do |index, product_option|
        options[index] = product_option if product_option[:option].present?
      end

      params[:product][:product_options_attributes] = options
    end

    permitted = params.expect(
      product: [:name,
                :model_no,
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

    coerce_custom_attributes!(permitted[:custom_attributes])

    permitted
  end

  def product_update_params
    permitted = params.expect(
      product: [:name,
                :model_no,
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
                {
                  custom_attributes: {},
                  sub_category_ids: []
                }]
    )

    coerce_custom_attributes!(permitted[:custom_attributes])

    permitted
  end

  # Casts each custom attribute's submitted string value to its CustomAttribute-defined
  # type (boolean / number), dropping entries left blank rather than saving them as 0.
  def coerce_custom_attributes!(custom_attributes)
    custom_attributes&.each do |key, value|
      active_record = CustomAttribute.find_by(label: key)

      case active_record.input_type
      when 'boolean'
        custom_attributes[key] = ActiveModel::Type::Boolean.new.cast(value)
      when 'number'
        case value['value']
        when ActionController::Parameters, Hash
          value['value'].to_hash.each do |val|
            if val[1] == ''
              custom_attributes[key]['value'].delete(val[0])
              custom_attributes.delete(key) if custom_attributes[key]['value'].empty?
            else
              custom_attributes[key]['value'][val[0]] = val[1].to_f
            end
          end
        else
          if value['value'] == ''
            custom_attributes.delete(key)
          else
            custom_attributes[key]['value'] = value['value'].to_f
          end
        end
      end
    end
  end

  def assign_brand_from_params(params)
    brand_id = params[:brand_id]

    if brand_id.present?
      Brand.find(brand_id)
    else
      Brand.new(params[:brand_attributes])
    end
  end
end
