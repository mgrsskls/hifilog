class UserController < ApplicationController
  def dashboard
    add_breadcrumb I18n.t('dashboard')
    @page_title = I18n.t('dashboard')

    unless user_signed_in?
      redirect_to new_user_session_url(redirect: dashboard_root_path)
      return
    end

    @active_menu = :dashboard
    @active_dashboard_menu = :dashboard

    data = PaperTrail::Version.where(whodunnit: current_user.id).group('item_type', 'event').count

    @products_created = get_data(data, 'Product', 'create')
    @products_edited = get_data(data, 'Product', 'update')
    @brands_created = get_data(data, 'Brand', 'create')
    @brands_edited = get_data(data, 'Brand', 'update')
  end

  def products
    if params[:user_name]
      @user = User.find_by!(user_name: params[:user_name])

      @is_public_profile = true
      add_breadcrumb I18n.t('users')
      add_breadcrumb @user.user_name
      @page_title = @user.user_name
    elsif user_signed_in?

      @active_dashboard_menu = :products
      @user = current_user
      add_breadcrumb I18n.t('dashboard'), dashboard_root_path
      add_breadcrumb I18n.t('headings.products'), dashboard_products_path
      @page_title = I18n.t('headings.products')
    end

    # if the visited profile is not visible to anyone and the visiting user is a different user
    if @user.hidden? && current_user != @user
      if user_signed_in?
        redirect_to root_url
      else
        redirect_to root_path
      end
      return
    end

    # if visited profile is not visible to logged out users and the current user is not logged in
    if @user.logged_in_only? && !user_signed_in?
      redirect_to new_user_session_url(redirect: URI.parse(user_path(user_name: @user.user_name)).path)
      return
    end

    all_products = @user.products.all.includes([:sub_categories, :brand]).order('LOWER(name)')

    if params[:category]
      sub_category = SubCategory.friendly.find(params[:category])
      @all_products = all_products.select { |product| sub_category.products.include?(product) }
    else
      @all_products = all_products
    end

    @all_categories = all_products.flat_map(&:sub_categories).uniq.sort_by { |c| c[:name].downcase }

    products_with_setup = @user.setups.includes([:products]).flat_map(&:products)
    @products_without_setup = (all_products - products_with_setup)

    if params[:user_name]
      render 'show'
    else
      render 'products'
    end
  end

  def bookmarks
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
    add_breadcrumb I18n.t('headings.bookmarks'), dashboard_bookmarks_path
    @page_title = I18n.t('headings.bookmarks')

    @active_dashboard_menu = :bookmarks

    bookmarks = current_user.bookmarks.includes(:product)
    @products = bookmarks.map(&:product)
  end

  private

  def get_data(data, model, event)
    data[[model, event]]
  end
end
