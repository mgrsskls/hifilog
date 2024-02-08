class UsersController < ApplicationController
  def index
    @users_by_products = ActiveRecord::Base.connection.execute("
      SELECT users.id, users.user_name, users.profile_visibility, users.created_at, COUNT(*)
      FROM users
      LEFT JOIN versions
      ON users.id = CAST(versions.whodunnit as bigint)
      GROUP BY users.id
      ORDER BY count DESC
    ")
  end

  def show
    @user = User.find_by!(user_name: params[:id])

    @is_public_profile = true
    add_breadcrumb I18n.t('users')
    add_breadcrumb @user.user_name
    @page_title = @user.user_name

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

    data = PaperTrail::Version.where(whodunnit: current_user.id).group('item_type', 'event').count

    @products_created = get_data(data, 'Product', 'create')
    @products_edited = get_data(data, 'Product', 'update')
    @brands_created = get_data(data, 'Brand', 'create')
    @brands_edited = get_data(data, 'Brand', 'update')
  end

  private

  def get_data(data, model, event)
    data[[model, event]] || 0
  end
end
