class UserController < ApplicationController
  before_action :authenticate_user!
  before_action :set_breadcrumb

  def dashboard
    @page_title = I18n.t('dashboard')
    @active_dashboard_menu = :dashboard

    data = PaperTrail::Version.where(whodunnit: current_user.id)
                              .select(:item_id)
                              .distinct
                              .group('item_type', 'event')
                              .count
    @products_created = get_data(data, 'Product', 'create')
    @products_edited = get_data(data, 'Product', 'update')
    @brands_created = get_data(data, 'Brand', 'create')
    @brands_edited = get_data(data, 'Brand', 'update')
  end

  def products
    add_breadcrumb I18n.t('headings.products'), dashboard_products_path
    @page_title = I18n.t('headings.products')
    @active_dashboard_menu = :products

    all_products = current_user.products.all.includes([:sub_categories, :brand]).order('LOWER(name)')

    if params[:category]
      sub_category = SubCategory.friendly.find(params[:category])
      @products = all_products.select { |product| sub_category.products.include?(product) }
    else
      @products = all_products
    end

    @categories = all_products.flat_map(&:sub_categories).uniq.sort_by { |c| c[:name].downcase }
    @setups = current_user.setups.joins(:products)
  end

  def bookmarks
    add_breadcrumb I18n.t('headings.bookmarks'), dashboard_bookmarks_path
    @page_title = I18n.t('headings.bookmarks')
    @active_dashboard_menu = :bookmarks

    bookmarks = current_user.bookmarks.includes(:product)
    @products = bookmarks.map(&:product)
  end

  def prev_owneds
    add_breadcrumb I18n.t('headings.prev_owneds'), dashboard_prev_owneds_path
    @page_title = I18n.t('headings.prev_owneds')
    @active_dashboard_menu = :prev_owneds

    prev_owneds = current_user.prev_owneds.includes(:product)
    @products = prev_owneds.map(&:product)
  end

  def contributions
    add_breadcrumb I18n.t('headings.contributions'), dashboard_contributions_path
    @page_title = I18n.t('headings.contributions')
    @active_dashboard_menu = :contributions

    @products = Product.joins(:versions)
                       .distinct
                       .includes([:brand])
                       .select('products.*, versions.event')
                       .where(versions: { item_type: 'Product', whodunnit: current_user.id })
                       .sort_by(&:display_name)
                       .group_by(&:event)
    @brands = Brand.joins(:versions)
                   .distinct
                   .select('brands.*, versions.event')
                   .where(versions: { item_type: 'Brand', whodunnit: current_user.id })
                   .order(:name)
                   .group_by(&:event)
  end

  private

  def get_data(data, model, event)
    data[[model, event]] || 0
  end

  def set_breadcrumb
    @active_menu = :dashboard
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
  end
end
