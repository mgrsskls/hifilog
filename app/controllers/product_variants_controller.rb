class ProductVariantsController < ApplicationController
  include ApplicationHelper

  # before_action :set_paper_trail_whodunnit, only: [:create, :update]
  # before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :authenticate_user!, only: [:changelog]
  # before_action :set_breadcrumb, only: [:show, :new, :edit, :changelog]
  before_action :set_breadcrumb, only: [:show, :changelog]
  before_action :set_active_menu
  before_action :find_product, only: [:show]

  def show
    @variant = @product.product_variants.friendly.find(params[:variant])
    @brand = @product.brand

    if user_signed_in?
      @possession = current_user.possessions.find_by(product_id: @product.id, product_variant_id: @variant.id)
      @bookmark = current_user.bookmarks.find_by(product_id: @product.id, product_variant_id: @variant.id)
      @prev_owned = current_user.prev_owneds.find_by(product_id: @product.id, product_variant_id: @variant.id)
      @setups = current_user.setups.includes(:possessions)
    end

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
    @page_title = "#{@product.display_name} #{@variant.name}"
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

  def find_product
    @product = Product.friendly.find(params[:product_id])

    return unless request.path != product_variant_path(product_id: @product.friendly_id, variant: params[:variant])

    # If an old id or a numeric id was used to find the record, then
    # the request path will not match the product_path, and we should do
    # a 301 redirect that uses the current friendly id.
    redirect_to URI.parse(
      product_variant_path(product_id: @product.friendly_id, variant: params[:variant])
    ).path, status: :moved_permanently
  end
end
