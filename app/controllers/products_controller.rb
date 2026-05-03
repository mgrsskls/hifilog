# frozen_string_literal: true

class ProductsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper
  include ApplicationHelper
  include FriendlyFinder

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_active_menu
  before_action :find_product, only: [:show]

  def show
    id = @product.id

    if user_signed_in?
      @possessions = current_user.possessions
                                 .includes(:product, :product_option, :setup_possession, :setup)
                                 .where(product_id: id, product_variant_id: nil)
                                 .order([:prev_owned, :period_from, :period_to, :created_at])
                                 .map { |possession| map_possession_to_presenter(possession) }
      @bookmark = current_user.bookmarks.find_by(item_id: id, item_type: 'Product')
      @note = current_user.notes.find_by(product_id: id, product_variant_id: nil)
      @setups = current_user.setups.includes(:possessions)
    end

    profile_visibility = user_signed_in? ? [1, 2] : 2
    @images = @product.possessions
                      .where(product_variant_id: nil)
                      .includes(:images_attachments)
                      .joins(:user)
                      .where(user: { profile_visibility: })
                      .where(active_storage_attachments: { record_type: 'Possession', name: 'images' })
                      .map { |possession| PossessionPresenter.new possession }
                      .flat_map(&:sorted_images)
                      .map { |image| ImagePresenter.new(image) }

    @contributors = ActiveRecord::Base.connection.execute("
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = #{id} AND versions.item_type = 'Product'
    ")

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
    custom_attributes = product_params[:custom_attributes]
    convert_custom_attributes!(custom_attributes) if custom_attributes.present?

    @product = Product.new(product_params)
    brand = assign_brand_from_params(product_params)

    product_options_attributes = params[:product_options_attributes]

    unless brand.save
      if product_options_attributes.present?
        process_product_options(@product,
                                product_options_attributes)
      end
      @categories = Category.includes([:sub_categories])
      @brand = brand
      render :new, status: :unprocessable_content and return
    end

    @product.brand_id = brand.id
    @product.discontinued = brand.discontinued ? true : product_params[:discontinued]

    if product_options_attributes.present?
      process_product_options(@product,
                              product_options_attributes)
    end

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
    old_name = @product.name
    old_model_no = @product.model_no
    @product.slug = nil if old_name != product_update_params[:name] || old_model_no != product_update_params[:model_no]

    custom_attributes = product_update_params[:custom_attributes]
    convert_custom_attributes!(custom_attributes) if custom_attributes.present?

    product_options_attributes = params[:product_options_attributes]
    if product_options_attributes.present?
      process_product_options(@product,
                              product_options_attributes)
    end

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

  def find_product
    @product = find_resource(Product, :id, path_helper: ->(product) { product_path(product) })
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

    permitted[:custom_attributes]&.each do |key, value|
      active_record = CustomAttribute.find_by(label: key)

      case active_record.input_type
      when 'boolean'
        permitted[:custom_attributes][key] = ActiveModel::Type::Boolean.new.cast(value)
      when 'number'
        case value['value']
        when ActionController::Parameters, Hash
          value['value'].to_hash.each do |val|
            if val[1] == ''
              permitted[:custom_attributes][key]['value'].delete(val[0])
              permitted[:custom_attributes].delete(key) if permitted[:custom_attributes][key]['value'].empty?
            else
              permitted[:custom_attributes][key]['value'][val[0]] = val[1].to_f
            end
          end
        else
          if value['value'] == ''
            permitted[:custom_attributes].delete(key)
          else
            permitted[:custom_attributes][key]['value'] = value['value'].to_f
          end
        end
      end
    end

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

    permitted[:custom_attributes]&.each do |key, value|
      active_record = CustomAttribute.find_by(label: key)

      case active_record.input_type
      when 'boolean'
        permitted[:custom_attributes][key] = ActiveModel::Type::Boolean.new.cast(value)
      when 'number'
        case value['value']
        when ActionController::Parameters, Hash
          value['value'].to_hash.each do |v|
            if v[1] == ''
              permitted[:custom_attributes][key]['value'].delete(v[0])
              permitted[:custom_attributes].delete(key) if permitted[:custom_attributes][key]['value'].empty?
            else
              permitted[:custom_attributes][key]['value'][v[0]] = v[1].to_f
            end
          end
        else
          if value['value'] == ''
            permitted[:custom_attributes].delete(key)
          else
            permitted[:custom_attributes][key]['value'] = value['value'].to_f
          end
        end
      end
    end

    permitted
  end

  def map_possession_to_presenter(possession)
    if possession.prev_owned
      PreviousPossessionPresenter.new(possession, :product)
    else
      PossessionPresenter.new(possession, :product)
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

  def process_product_options(product, options_attributes)
    options_attributes.each_value do |attribute|
      model_no = attribute[:model_no]
      option = attribute[:option]
      id = attribute[:id]
      product_options = product.product_options

      if id.present?
        product_option = product_options.find(id)

        if option.present? || model_no.present?
          product_option.update(option:, model_no:)
        else
          product_option.delete
        end
      elsif option.present?
        product_options << ProductOption.new(option:, model_no:)
      end
    end
  end

  def convert_custom_attributes!(custom_attributes)
    custom_attributes.each do |key, value|
      active_record = CustomAttribute.find_by(label: key)

      case active_record.input_type
      when 'boolean'
        custom_attributes[key] = ActiveModel::Type::Boolean.new.cast(value)
      when 'number'
        case value['value']
        when ActionController::Parameters, Hash
          value['value'].to_hash.each do |val|
            custom_attributes[key]['value'][val[0]] = val[1].to_f
          end
        else
          custom_attributes[key]['value'] = value['value'].to_f
        end
      end
    end
  end
end
