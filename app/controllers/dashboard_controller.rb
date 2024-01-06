class DashboardController < ApplicationController
  before_action :authenticate_user!

  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("dashboard")

  def show
    @user = User.find(params[:id])
  end

  def products
    add_breadcrumb I18n.t("headings.products"), :dashboard_products_path

    @active_menu = :dashboard
    @active_dashboard_menu = :products

    all_products = current_user.products.all.order("LOWER(name)")


    if params[:category]
      @sub_category = SubCategory.friendly.find(params[:category])
      @all_products = current_user.products.select { |product| @sub_category.products.include?(product) }
    else
      @all_products = all_products
    end

    @all_categories = all_products.flat_map{ |product| product.sub_categories }.uniq.sort_by{|c| c[:name].downcase}

    products_with_setup = current_user.setups.flat_map { |setup| setup.products }
    @products_without_setup = (all_products - products_with_setup)
  end

  def bookmarks
    add_breadcrumb I18n.t("headings.bookmarks"), :dashboard_bookmarks_path

    @active_menu = :dashboard
    @active_dashboard_menu = :bookmarks

    bookmarks = Bookmark.where(user_id: current_user.id)
    @products = bookmarks.map { |bookmark| Product.find(bookmark.product_id) }
  end
end
