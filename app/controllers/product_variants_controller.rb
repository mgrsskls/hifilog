# frozen_string_literal: true

class ProductVariantsController < ApplicationController
  include ApplicationHelper

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_active_menu
  before_action :find_product_and_variant, only: [:show]

  def show
    @brand = @product.brand
    product_id = @product.id

    product_variant_id = @product_variant.id

    if user_signed_in?
      @possessions = map_possessions_to_presenter current_user.possessions
                                                              .includes([:product])
                                                              .includes([:product_variant])
                                                              .includes([:setup_possession])
                                                              .includes([:setup])
                                                              .includes([:product_option])
                                                              .where(
                                                                product_id:,
                                                                product_variant_id:
                                                              )
                                                              .order([
                                                                       :prev_owned,
                                                                       :period_from,
                                                                       :period_to,
                                                                       :created_at
                                                                     ])

      @bookmark = current_user.bookmarks.find_by(item_id: product_variant_id, item_type: 'ProductVariant')
      @note = current_user.notes.find_by(product_variant_id:)
      @setups = current_user.setups
    end

    @images = @product_variant.possessions
                              .includes([:images_attachments])
                              .joins(:user)
                              .where(user: { profile_visibility: user_signed_in? ? [1, 2] : 2 })
                              .select { |possession| possession.images.attached? }
                              .map { |possession| PossessionPresenter.new possession }
                              .flat_map(&:sorted_images)
                              .map { |image| ImagePresenter.new image }

    @custom_attributes = CustomAttribute.where(label: @product.custom_attributes&.keys).index_by(&:label)

    @contributors = ActiveRecord::Base.connection.execute("
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = #{product_id} AND versions.item_type = 'Product'
    ")

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

    old_name = @product_variant.name
    @product_variant.slug = nil if old_name != product_variant_update_params[:name]

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
    variant_id = params[:id]

    @product = Product.friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(variant_id)

    product_friendly_id = @product.friendly_id
    variant_path = product_variant_path(product_id: product_friendly_id, id: variant_id)

    return unless request.path != variant_path

    # If an old id or a numeric id was used to find the record, then
    # the request path will not match the product_path, and we should do
    # a 301 redirect that uses the current friendly id.
    redirect_to URI.parse(
      variant_path
    ).path, status: :moved_permanently
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
