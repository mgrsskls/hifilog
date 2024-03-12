class UsersController < ApplicationController
  before_action :set_breadcrumb, except: [:show, :prev_owneds]

  def index
    @page_title = I18n.t('headings.users')
    @users_by_products = User.find_by_sql('
      SELECT t2.id, t2.user_name, t2.profile_visibility, t2.created_at, COUNT(t2.id) as count FROM (
        SELECT
          users.id,
          users.user_name,
          users.profile_visibility,
          users.created_at,
          versions.item_id
        FROM "versions"
        INNER JOIN users
        ON users.id = CAST(versions.whodunnit as bigint)
        GROUP BY users.id, versions.item_id
      ) AS t2
      GROUP BY id, user_name, profile_visibility, created_at
      ORDER BY count DESC
    ')
  end

  def show
    @user = User.where('lower(user_name) = ?', (params[:user_id].presence || params[:id]).downcase).first

    return render 'not_found', status: :not_found if @user.nil?

    unless current_user == @user
      redirect_path = get_redirect_if_unauthorized(@user, false)
      return redirect_to redirect_path if redirect_path
    end

    setup_user_page(@user)

    if params[:setup]
      setup = @user.setups.find(params[:setup])
      all_possessions = setup.possessions
                             .joins(:product)
                             .includes([product: [{ sub_categories: :category }, :brand]])
                             .order('LOWER(products.name)')
                             .map { |bookmark| ItemPresenter.new(bookmark) }
    else
      all_possessions = @user.possessions
                             .joins(:product)
                             .includes([product: [{ sub_categories: :category }, :brand]])
                             .order('LOWER(products.name)')
                             .map { |bookmark| ItemPresenter.new(bookmark) }
    end

    if params[:category]
      @sub_category = SubCategory.friendly.find(params[:category])
      @possessions = all_possessions.select { |possession| @sub_category.products.include?(possession.product) }
    else
      @possessions = all_possessions
    end

    @categories = all_possessions.map(&:product)
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
                                         path: (
                                           if setup
                                             user_setup_path(
                                               user_id: @user.user_name.downcase,
                                               category: sub_category.friendly_id,
                                               setup: setup.id
                                             )
                                           else
                                             user_path(id: @user.user_name.downcase, category: sub_category.friendly_id)
                                           end
                                         )
                                       }
                                     }
                                   ]
                                 }
    @reset_path = @user.profile_path

    render 'show', locals: { include_images: true }
  end

  def prev_owneds
    @user = User.where('lower(user_name) = ?', (params[:user_id].presence || params[:id]).downcase).first

    return render 'not_found', status: :not_found if @user.nil?

    unless current_user == @user
      redirect_path = get_redirect_if_unauthorized(@user, true)
      return redirect_to redirect_path if redirect_path
    end

    setup_user_page(@user)

    all_prev_owneds = @user.prev_owneds
                           .joins(:product)
                           .includes([product: [{ sub_categories: :category }, :brand]])
                           .order('LOWER(products.name)')
                           .map { |prev_owned| ItemPresenter.new(prev_owned) }

    if params[:category]
      @sub_category = SubCategory.friendly.find(params[:category])
      @possessions = all_prev_owneds.select { |possession| @sub_category.products.include?(possession.product) }
    else
      @possessions = all_prev_owneds
    end

    @categories = all_prev_owneds.map(&:product)
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

    render 'show', locals: { include_images: false }
  end

  private

  def get_data(data, model, event)
    data[[model, event]] || 0
  end

  def set_breadcrumb
    add_breadcrumb I18n.t('users')
  end

  def setup_user_page(user)
    @page_title = user.user_name

    data = PaperTrail::Version.where(whodunnit: user.id)
                              .select(:item_id)
                              .distinct
                              .group('item_type', 'event')
                              .count

    @products_created = get_data(data, 'Product', 'create')
    @products_edited = get_data(data, 'Product', 'update')
    @brands_created = get_data(data, 'Brand', 'create')
    @brands_edited = get_data(data, 'Brand', 'update')

    return unless current_user == user

    @active_menu = :dashboard
    @active_dashboard_menu = :profile
  end

  def get_redirect_if_unauthorized(user, prev_owneds)
    return if user.visible?

    # if visited profile is not visible to logged out users and the current user is logged in
    return if user.logged_in_only? && user_signed_in?

    # if the visited profile is not visible to anyone and the visiting user is a different user
    return root_url if user.hidden? && current_user != user

    redir = prev_owneds ? user_previous_products_path(user_name: user.user_name) : user_path(user_name: user.user_name)
    new_user_session_url(redirect: URI.parse(redir).path)
  end
end
