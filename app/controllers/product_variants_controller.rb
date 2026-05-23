# frozen_string_literal: true

class ProductVariantsController < ApplicationController
  include ApplicationHelper
  include ProductCatalogShow

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_noindex_meta_robots, only: [:new, :edit, :create, :update, :changelog]
  before_action :set_active_menu
  before_action :find_product_and_variant, only: [:show]

  def show
    @brand = @product.brand

    assign_product_catalog_show_data(product: @product, product_variant: @product_variant)

    page_title("#{@product.display_name} #{@product_variant.short_name}")
    set_meta_desc
  end

  def new
    @product = Product.friendly.find(params[:product_id])
    @product_variant = ProductVariant.new(product: @product)
    @brand = @product.brand

    page_title("#{I18n.t('product_variant.new.link')} — #{@product.display_name}")
  end

  def edit
    @product = Product.friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:id])
    @brand = @product.brand
    page_title(I18n.t('edit_record', name: @product_variant.display_name))
  end

  def create
    @product = Product.find(params[:product_id])
    @product_variant = ProductVariant.new(product_variant_params)
    @product.product_variants << @product_variant
    @brand = @product.brand
    @product_variant.discontinued = @brand.discontinued ? true : product_variant_params[:discontinued]

    product_variant_options = @product_variant.product_options
    product_options_attributes = params[:product_options_attributes]

    if product_options_attributes.present?
      product_options_attributes.each do |attribute|
        attr = attribute[1]
        option = attr[:option]
        id = attr[:id]

        if id.present?
          product_variant_option = product_variant_options.find(id)
          if option.present?
            product_variant_option.update(option:)
          else
            product_variant_option.delete
          end
        elsif option.present?
          product_variant_options << ProductOption.new(option:)
        end
      end
    end

    if @product_variant.save
      redirect_to product_variant_url(
        product_id: @product.friendly_id,
        id: @product_variant.friendly_id
      )
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @product_variant = ProductVariant.find(params[:id])

    product_options_attributes = params[:product_options_attributes]

    if product_options_attributes.present?
      variant_product_options = @product_variant.product_options
      product_options_attributes.each do |attribute|
        attr = attribute[1]
        model_no = attr[:model_no]
        option = attr[:option]
        id = attr[:id]

        if id.present?
          variant_product_option = variant_product_options.find(id)

          if option.present? || model_no.present?
            variant_product_option.update(option:,
                                          model_no:)
          else
            variant_product_option.delete
          end
        elsif option.present?
          variant_product_options << ProductOption.new(option:,
                                                       model_no:)
        end
      end
    end

    if @product_variant.update(product_variant_update_params)
      redirect_to URI.parse(
        product_variant_url(
          product_id: @product_variant.product.friendly_id,
          id: @product_variant.friendly_id
        )
      ).path
    else
      @product = Product.find(@product_variant.product_id)
      render :edit, status: :unprocessable_content
    end
  end

  def changelog
    @product = Product.friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:id])
    @brand = @product.brand
    @versions = filter_versions(@product_variant.versions)
  end

  private

  def set_noindex_meta_robots
    @meta_robots = 'noindex, follow'
  end

  def set_meta_desc
    return if @product.description.blank?

    @meta_desc = ActionController::Base.helpers.truncate(
      ActionController::Base.helpers.strip_tags(@product.formatted_description),
      length: 200
    )
  end

  def set_active_menu
    @active_menu = :products
  end

  def find_product_and_variant
    @product = Product.includes(:brand, sub_categories: :category).friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:id])
    return if request.path == product_variant_path(product_id: @product.friendly_id, id: @product_variant.friendly_id)

    redirect_to URI.parse(
      product_variant_path(product_id: @product.friendly_id, id: @product_variant.friendly_id)
    ).path, status: :moved_permanently and return
  end

  def product_variant_params
    params.expect(
      product_variant: [:name,
                        :model_no,
                        :release_day,
                        :release_month,
                        :release_year,
                        :discontinued,
                        :discontinued_day,
                        :discontinued_month,
                        :discontinued_year,
                        :diy_kit,
                        :description,
                        :price,
                        :price_currency,
                        :product_id,
                        { product_options_attributes: {} }]
    )
  end

  def product_variant_update_params
    params.expect(
      product_variant: [:name,
                        :model_no,
                        :release_day,
                        :release_month,
                        :release_year,
                        :discontinued,
                        :discontinued_day,
                        :discontinued_month,
                        :discontinued_year,
                        :diy_kit,
                        :description,
                        :price,
                        :price_currency,
                        :product_id,
                        :comment]
    )
  end
end
