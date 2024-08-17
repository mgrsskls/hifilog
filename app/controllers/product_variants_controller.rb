class ProductVariantsController < ApplicationController
  include ApplicationHelper

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_breadcrumb, only: [:show, :new, :edit, :changelog]
  before_action :set_active_menu
  before_action :find_product_and_variant, only: [:show]

  def show
    @brand = @product.brand

    if user_signed_in?
      @possessions = current_user.possessions
                                 .where(
                                   product_id: @product.id,
                                   product_variant_id: @variant.id,
                                 )
                                 .map do |possession|
                                   if possession.prev_owned
                                     PreviousPossessionPresenter.new(possession)
                                   else
                                     CurrentPossessionPresenter.new(possession)
                                   end
                                 end
      @bookmark = current_user.bookmarks.find_by(product_id: @product.id, product_variant_id: @variant.id)
      @note = current_user.notes.find_by(product_id: @product.id, product_variant_id: @variant.id)
      @setups = current_user.setups.includes(:possessions)
    end

    @public_possessions_with_image = @variant.possessions
                                             .joins(:user)
                                             .where(user: { profile_visibility: user_signed_in? ? [1, 2] : 2 })
                                             .select { |possession| possession.image.attached? }

    @contributors = ActiveRecord::Base.connection.execute("
      SELECT DISTINCT
        users.id, users.user_name, users.profile_visibility,
        versions.item_type, versions.item_id FROM users
      JOIN versions
      ON users.id = CAST(versions.whodunnit AS integer)
      WHERE versions.item_id = #{@product.id} AND versions.item_type = 'Product'
    ")

    add_breadcrumb @product.display_name, @product
    add_breadcrumb @variant.short_name
    @page_title = "#{@product.display_name} #{@variant.short_name}"
  end

  def new
    @product = Product.friendly.find(params[:product_id])
    @product_variant = ProductVariant.new(product: @product)

    add_breadcrumb @product.display_name, @product
    add_breadcrumb I18n.t('new_variant.link')
    @page_title = "#{I18n.t('new_variant.link')} — #{@product.display_name}"
  end

  def create
    @product_variant = ProductVariant.new(product_variant_params)
    @product = @product_variant.product
    @product_variant.discontinued = @product.brand.discontinued ? true : product_params[:discontinued]

    if @product_variant.save
      redirect_to product_variant_url(product_id: @product.friendly_id, variant: @product_variant.friendly_id)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @product = Product.friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:variant])
    @page_title = I18n.t('edit_record', name: @product_variant.display_name)

    add_breadcrumb @product.display_name, @product
    add_breadcrumb @product_variant.short_name, product_variant_path(
      product_id: @product.friendly_id,
      variant: @product_variant.friendly_id
    )
    add_breadcrumb I18n.t('edit')
  end

  def update
    @product_variant = ProductVariant.find(params[:id])

    old_name = @product_variant.name
    @product_variant.slug = nil if old_name != product_variant_update_params[:name]

    if @product_variant.update(product_variant_update_params)
      redirect_to URI.parse(
        product_variant_url(
          product_id: @product_variant.product.friendly_id,
          variant: @product_variant.friendly_id
        )
      ).path
    else
      @product = Product.find(@product_variant.product_id)
      render :edit, status: :unprocessable_entity
    end
  end

  def changelog
    @product = Product.friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:variant])
    @brand = @product.brand
    @versions = @product_variant.versions.select do |v|
      log = get_changelog(v.object_changes)
      log.length > 1 || (log.length == 1 && log['slug'].nil?)
    end

    add_breadcrumb @product.display_name, @product.path
    add_breadcrumb @product_variant.short_name, @product_variant.path
    add_breadcrumb I18n.t('headings.changelog')
  end

  private

  def set_active_menu
    @active_menu = :products
  end

  def set_breadcrumb
    add_breadcrumb I18n.t('headings.products'), products_path
  end

  def find_product_and_variant
    @product = Product.friendly.find(params[:product_id])
    @variant = @product.product_variants.friendly.find(params[:variant])

    return unless request.path != product_variant_path(product_id: @product.friendly_id, variant: params[:variant])

    # If an old id or a numeric id was used to find the record, then
    # the request path will not match the product_path, and we should do
    # a 301 redirect that uses the current friendly id.
    redirect_to URI.parse(
      product_variant_path(product_id: @product.friendly_id, variant: params[:variant])
    ).path, status: :moved_permanently
  end

  def product_variant_params
    params.require(:product_variant).permit(
      :name,
      :release_day,
      :release_month,
      :release_year,
      :discontinued,
      :discontinued_day,
      :discontinued_month,
      :discontinued_year,
      :description,
      :price,
      :price_currency,
      :product_id
    )
  end

  def product_variant_update_params
    params.require(:product_variant).permit(
      :name,
      :release_day,
      :release_month,
      :release_year,
      :discontinued,
      :discontinued_day,
      :discontinued_month,
      :discontinued_year,
      :description,
      :price,
      :price_currency,
      :product_id,
      :comment
    )
  end
end
