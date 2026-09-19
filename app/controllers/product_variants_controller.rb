# frozen_string_literal: true

class ProductVariantsController < ApplicationController
  include FriendlyFinder
  include ProductCatalogShow
  include ProductOptionsAssignable

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update]
  before_action :set_noindex_meta_robots, only: [:new, :edit, :create, :update, :changelog, :similar]
  before_action :set_active_menu
  before_action :find_product_and_variant, only: [:show, :similar]

  def show
    @brand = @product.brand

    assign_product_catalog_show_data(product: @product, product_variant: @product_variant)

    page_title(@product_variant.qualified_name)
    set_meta_desc
  end

  # The full, paginated "Similar Products" list of a variant (README, "Similar Products"). The list
  # is the list of the parent product, because the ranking uses the attributes of the product. The
  # sidebar shows the variant. Like the product version, the page is noindex.
  def similar
    @products = SimilarProducts.page(product: @product, page: params[:page])
    @custom_attributes = @product.custom_attributes_resources if @product.custom_attributes&.any?

    page_title("#{I18n.t('similar_products.heading')} — #{@product_variant.display_name}")
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

    product_options_attributes = params[:product_options_attributes]
    assign_product_options(@product_variant, product_options_attributes) if product_options_attributes.present?

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
    assign_product_options(@product_variant, product_options_attributes) if product_options_attributes.present?

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
    @meta_desc = @product_variant.meta_desc
  end

  def set_active_menu
    @active_menu = :products
  end

  def find_product_and_variant
    @product = Product.includes(:brand, { sub_categories: :category }, { product_series: :brand })
                      .friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:id])

    redirect_to_canonical_path(canonical_variant_path) { nil }
  end

  def canonical_variant_path
    ids = { product_id: @product.friendly_id, id: @product_variant.friendly_id }
    action_name == 'similar' ? product_variant_similar_path(**ids) : product_variant_path(**ids)
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
