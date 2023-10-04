class DashboardController < ApplicationController
  before_action :authenticate_user!

  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("dashboard")

  def index
    add_breadcrumb I18n.t("overview")
    @active_menu = :dashboard
    @active_dashboard_menu = :overview
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

    products_with_room = current_user.rooms.flat_map { |room| room.products }
    @products_without_room = (all_products - products_with_room)
  end
end
