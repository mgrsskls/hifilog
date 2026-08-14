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

    page_title(@product.display_name, @product.meta_desc)
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
                    :abbreviation,
                    :legal_name,
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
  #
  # One cached lookup for the whole submission rather than a query per key. The definitions are
  # cached anyway for CustomAttribute.normalize_units, which runs further down the same save, so
  # the per-key find_by was issuing N queries for rows the request had already loaded.
  def coerce_custom_attributes!(custom_attributes)
    return if custom_attributes.blank?

    definitions = CustomAttribute.all_cached.index_by(&:label)

    discard_unknown_custom_attributes!(custom_attributes, definitions)

    custom_attributes.each do |key, value|
      case definitions.fetch(key).input_type
      when 'boolean'
        custom_attributes[key] = ActiveModel::Type::Boolean.new.cast(value)
      when 'number'
        coerce_number_custom_attribute!(custom_attributes, key, value)
      end
    end
  end

  # A label no definition backs is dropped, not skipped.
  #
  # It used to raise on `active_record.input_type`, so a crafted or stale submission -- a form
  # rendered before a label was renamed, say -- was a 500. Merely skipping it would be no better
  # in the long run: the key would persist into the jsonb uninterpretable, where nothing can
  # display, filter or score it and only an orphan-key audit would ever find it.
  #
  # Keys are collected before any deletion so the hash is not mutated mid-iteration.
  def discard_unknown_custom_attributes!(custom_attributes, definitions)
    unknown = custom_attributes.keys.reject { |key| definitions.key?(key) }

    unknown.each { |key| custom_attributes.delete(key) }
  end

  # A figure that cannot be read is dropped exactly like a blank one.
  #
  # `to_f` answers 0.0 for anything it does not understand, so "0,5" from a contributor using a
  # decimal comma was stored as 0 -- indistinguishable from a measured zero, and invisible to
  # the person who typed it. "12abc" became 12 the same way. Absent is the honest answer: the
  # completeness prompts then ask for the figure again, where a 0 would look answered.
  #
  # entity_form.js normalises the separator before submit (see parseTypedNumber); this is what
  # catches the submission when it has not run.
  def coerce_number_custom_attribute!(custom_attributes, key, value)
    entry = custom_attributes[key]

    case value['value']
    when ActionController::Parameters, Hash
      # Iterates a copy so the original can be deleted from while walking it.
      value['value'].to_hash.each do |input, submitted|
        number = numeric_param(submitted)

        if number.nil?
          entry['value'].delete(input)
          custom_attributes.delete(key) if entry['value'].empty?
        else
          entry['value'][input] = number
        end
      end
    else
      number = numeric_param(value['value'])

      number.nil? ? custom_attributes.delete(key) : entry['value'] = number
    end
  end

  # Strict where `to_f` is lenient: nil rather than 0.0 for anything that is not wholly a
  # number. Blank included, which is why the caller needs no separate blank branch.
  def numeric_param(value)
    Float(value.to_s, exception: false)
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
