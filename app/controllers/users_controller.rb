class UsersController < ApplicationController
  add_breadcrumb APP_NAME, :root_path
  add_breadcrumb I18n.t('users')

  def show
    if params[:random_username]
      @user = User.where(random_username: params[:random_username]).first
    elsif params[:username]
      @user = User.where(user_name: params[:username]).first
    end

    if @user.nil?
      render '404', layout: true, status: :not_found
      return
    end

    # if the visited profile is not visible to anyone and the visiting user is a different user
    if @user.profile_visibility == 0 && current_user != @user
      if user_signed_in?
        redirect_to root_url
      else
        redirect_to new_user_session_url
      end
    end

    # if visited profile is not visible to logged out users and the current user is not logged in
    redirect_to new_user_session_url if @user.profile_visibility == 1 && !user_signed_in?

    add_breadcrumb @user.display_name

    all_products = @user.products.all.order('LOWER(name)')
    if params[:category]
      @sub_category = SubCategory.friendly.find(params[:category])
      @all_products = @user.products.select { |product| @sub_category.products.include?(product) }
    else
      @all_products = all_products
    end

    @all_categories = all_products.flat_map(&:sub_categories).uniq.sort_by { |c| c[:name].downcase }

    products_with_setup = @user.setups.flat_map(&:products)
    @products_without_setup = (all_products - products_with_setup)
  end
end
