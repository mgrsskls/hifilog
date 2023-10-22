class UsersController < ApplicationController
  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("dashboard")

  def show
    @user = User.find(params[:id])

    # if the visited profile is not visible to anyone and the visiting user is a different user
    if @user.profile_visibility == 0 && current_user != @user
      if user_signed_in?
        redirect_to root_url
      else
        redirect_to new_user_session_url
      end
    end

    # if visited profile is not visible to logged out users and the current user is not logged in
    if @user.profile_visibility == 1 && !user_signed_in?
      redirect_to new_user_session_url
    end

    add_breadcrumb I18n.t("headings.products"), :dashboard_products_path

    @active_menu = :dashboard
    @active_dashboard_menu = :products

    all_products = @user.products.all.order("LOWER(name)")
    if params[:category]
      @sub_category = SubCategory.friendly.find(params[:category])
      @all_products = @user.products.select { |product| @sub_category.products.include?(product) }
    else
      @all_products = all_products
    end

    @all_categories = all_products.flat_map{ |product| product.sub_categories }.uniq.sort_by{|c| c[:name].downcase}

    products_with_room = @user.rooms.flat_map { |room| room.products }
    @products_without_room = (all_products - products_with_room)
  end
end
