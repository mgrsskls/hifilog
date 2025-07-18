class ProductVariantsController < ApplicationController
  include ApplicationHelper

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_active_menu
  before_action :find_product_and_variant, only: [:show]

  def show
    @brand = @product.brand

    if user_signed_in?
      @possessions = map_possessions_to_presenter current_user.possessions
                                                              .includes([:product])
                                                              .includes([:product_variant])
                                                              .includes([:setup_possession])
                                                              .includes([:setup])
                                                              .includes([:product_option])
                                                              .where(
                                                                product_id: @product.id,
                                                                product_variant_id: @product_variant.id,
                                                              )
                                                              .order([
                                                                       :prev_owned,
                                                                       :period_from,
                                                                       :period_to,
                                                                       :created_at
                                                                     ])

      @bookmark = current_user.bookmarks.find_by(product_id: @product.id, product_variant_id: @product_variant.id)
      @note = current_user.notes.find_by(product_variant_id: @product_variant.id)
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

    @contributors = ActiveRecord::Base.connection.execute("
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = #{@product.id} AND versions.item_type = 'Product'
    ")

    @page_title = "#{@product.display_name} #{@product_variant.short_name}"
    set_meta_desc
  end

  def new
    @product = Product.friendly.find(params[:product_id])
    @product_variant = ProductVariant.new(product: @product)
    @brand = @product.brand

    @page_title = "#{I18n.t('product_variant.new.link')} — #{@product.display_name}"
  end

  def edit
    @product = Product.friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:id])
    @brand = @product.brand
    @page_title = I18n.t('edit_record', name: @product_variant.display_name)
  end

  def create
    @product = Product.find(params[:product_id])
    @product_variant = ProductVariant.new(product_variant_params)
    @product.product_variants << @product_variant
    @brand = @product.brand
    @product_variant.discontinued = @product.brand.discontinued ? true : product_variant_params[:discontinued]

    if params[:product_options_attributes].present?
      params[:product_options_attributes].each do |option|
        if option[1][:id].present?
          if option[1][:option].present?
            @product_variant.product_options.find(option[1][:id]).update(option: option[1][:option])
          else
            @product_variant.product_options.find(option[1][:id]).delete
          end
        elsif option[1][:option].present?
          @product_variant.product_options << ProductOption.new(option: option[1][:option])
        end
      end
    end

    if @product_variant.save
      redirect_to product_variant_url(
        product_id: @product.friendly_id,
        id: @product_variant.friendly_id
      )
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @product_variant = ProductVariant.find(params[:id])

    old_name = @product_variant.name
    @product_variant.slug = nil if old_name != product_variant_update_params[:name]

    if params[:product_options_attributes].present?
      params[:product_options_attributes].each do |option|
        if option[1][:id].present?
          if option[1][:option].present? || option[1][:model_no].present?
            @product_variant.product_options.find(option[1][:id]).update(option: option[1][:option],
                                                                         model_no: option[1][:model_no])
          else
            @product_variant.product_options.find(option[1][:id]).delete
          end
        elsif option[1][:option].present?
          @product_variant.product_options << ProductOption.new(option: option[1][:option],
                                                                model_no: option[1][:model_no])
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
      render :edit, status: :unprocessable_entity
    end
  end

  def changelog
    @product = Product.friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:id])
    @brand = @product.brand
    @versions = @product_variant.versions.select do |v|
      log = get_changelog(v.object_changes)
      log.length > 1 || (log.length == 1 && log['slug'].nil?)
    end
  end

  private

  def set_meta_desc
    return if @product.description.blank?

    @meta_desc = ActionController::Base.helpers.truncate(
      ActionController::Base.helpers.strip_tags(@product.formatted_description),
      length: 155
    )
  end

  def set_active_menu
    @active_menu = :products
  end

  def find_product_and_variant
    @product = Product.friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:id])

    return unless request.path != product_variant_path(product_id: @product.friendly_id, id: params[:id])

    # If an old id or a numeric id was used to find the record, then
    # the request path will not match the product_path, and we should do
    # a 301 redirect that uses the current friendly id.
    redirect_to URI.parse(
      product_variant_path(product_id: @product.friendly_id, id: params[:id])
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
                        { product_options_attributes: {} }],
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
                        :comment],
    )
  end
end
