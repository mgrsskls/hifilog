class UsersController < ApplicationController
  before_action :set_breadcrumb

  def index
    @page_title = I18n.t('headings.users')
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

    redirect_path = get_redirect_if_unauthorized(@user)
    return redirect_to redirect_path if redirect_path

    setup_user_page(@user)

    all_products = @user.products.all.includes([:sub_categories, :brand]).order('LOWER(name)')

    if params[:category]
      @sub_category = SubCategory.friendly.find(params[:category])
      @products = all_products.select { |product| @sub_category.products.include?(product) }
    else
      @products = all_products
    end

    @categories = all_products.includes([sub_categories: [:category]])
                              .flat_map(&:sub_categories)
                              .sort_by(&:name)
                              .uniq
                              .group_by(&:category)
                              .sort_by { |category| category[0].order }
                              # rubocop:disable Style/BlockDelimiters
                              .map { |c|
                                [
                                  c[0],
                                  c[1].map { |sub_category|
                                    # rubocop:enable Style/BlockDelimiters
                                    {
                                      name: sub_category.name,
                                      friendly_id: sub_category.friendly_id,
                                      path: user_path(id: @user.user_name, category: sub_category.friendly_id)
                                    }
                                  }
                                ]
                              }
    @reset_path = user_path(id: @user.user_name)
  end

  def prev_owneds
    @user = User.find_by!(user_name: params[:user_id])

    redirect_path = get_redirect_if_unauthorized(@user, true)
    return redirect_to redirect_path if redirect_path

    setup_user_page(@user)

    all_products = Product.where(id: @user.prev_owneds.map(&:product_id))
                          .order('LOWER(products.name)')
                          .includes([:sub_categories, :brand])

    if params[:category]
      @sub_category = SubCategory.friendly.find(params[:category])
      @products = all_products.select { |product| @sub_category.products.include?(product) }
    else
      @products = all_products
    end

    @categories = all_products.includes([sub_categories: [:category]])
                              .flat_map(&:sub_categories)
                              .sort_by(&:name)
                              .uniq
                              .group_by(&:category)
                              .sort_by { |category| category[0].order }
                              # rubocop:disable Style/BlockDelimiters
                              .map { |c|
                                [
                                  c[0],
                                  c[1].map { |sub_category|
                                    # rubocop:enable Style/BlockDelimiters
                                    {
                                      name: sub_category.name,
                                      friendly_id: sub_category.friendly_id,
                                      path: user_previous_products_path(
                                        id: @user.user_name,
                                        category: sub_category.friendly_id
                                      )
                                    }
                                  }
                                ]
                              }
    @reset_path = user_previous_products_path(id: @user.user_name)

    render 'show'
  end

  private

  def get_data(data, model, event)
    data[[model, event]] || 0
  end

  def set_breadcrumb
    add_breadcrumb I18n.t('users')
  end

  def setup_user_page(user)
    add_breadcrumb user.user_name
    @page_title = user.user_name

    data = PaperTrail::Version.where(whodunnit: user.id).group('item_type', 'event').count

    @products_created = get_data(data, 'Product', 'create')
    @products_edited = get_data(data, 'Product', 'update')
    @brands_created = get_data(data, 'Brand', 'create')
    @brands_edited = get_data(data, 'Brand', 'update')
  end

  def get_redirect_if_unauthorized(user, prev_owneds)
    return if user.visible?

    # if visited profile is not visible to logged out users and the current user is not logged in
    return if user.logged_in_only? && user_signed_in?

    # if the visited profile is not visible to anyone and the visiting user is a different user
    return root_url if user.hidden? && current_user != user

    redir = prev_owneds ? user_previous_products_path(user_name: user.user_name) : user_path(user_name: user.user_name)
    new_user_session_url(redirect: URI.parse(redir).path)
  end
end
