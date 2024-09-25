class UsersController < ApplicationController
  include HistoryHelper
  include Possessions

  before_action :set_breadcrumb, only: [:index]

  def index
    @page_title = User.model_name.human(count: 2)
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
    @user = setup_user_page
    return unless @user

    @setup = @user.setups.find(params[:setup]) if params[:setup]
    possessions = @setup ? @setup.possessions : @user.possessions.where(prev_owned: false)

    all = map_possessions_to_presenter get_possessions_for_user(possessions:)
    @sub_category = SubCategory.friendly.find(params[:category]) if params[:category].present?
    @possessions = if @sub_category
                     all.select { |p| p.sub_categories.include?(@sub_category) }
                   else
                     all
                   end
    @categories = get_grouped_sub_categories(possessions: all)

    @render_since = true
    @render_period = false

    @heading = if @setup.present?
                 @setup.name
               else
                 I18n.t('headings.current_products')
               end

    render 'show'
  end

  def prev_owneds
    @user = setup_user_page
    return unless @user

    all = map_possessions_to_presenter get_possessions_for_user(possessions: @user.possessions.where(prev_owned: true))
    @sub_category = SubCategory.friendly.find(params[:category]) if params[:category].present?
    @possessions = if @sub_category
                     all.select { |p| p.sub_categories.include?(@sub_category) }
                   else
                     all
                   end
    @categories = get_grouped_sub_categories(possessions: all)

    @render_since = false
    @render_period = true
    @heading = I18n.t('headings.prev_owneds')

    render 'show'
  end

  def history
    @user = setup_user_page
    return unless @user

    @possessions = get_history_possessions(@user.possessions)
    @heading = I18n.t('headings.history')
  end

  def contributions
    @user = setup_user_page
    return unless @user

    data = PaperTrail::Version.where(whodunnit: @user.id)
                              .select(:item_id)
                              .distinct
                              .group('item_type', 'event')
                              .count

    @products_created = get_data(data, 'Product', 'create')
    @products_edited = get_data(data, 'Product', 'update')
    @brands_created = get_data(data, 'Brand', 'create')
    @brands_edited = get_data(data, 'Brand', 'update')

    @heading = I18n.t('headings.contributions')
  end

  private

  def get_data(data, model, event)
    data[[model, event]] || 0
  end

  def set_breadcrumb
    add_breadcrumb User.model_name.human(count: 2)
  end

  def setup_user_page
    user = User.find_by('lower(user_name) = ?', (params[:user_id].presence || params[:id]).downcase)

    if user.nil? || (user.hidden? && current_user != user) || (user.logged_in_only? && !user_signed_in?)
      render 'not_found', status: :not_found
      return nil
    end

    @page_title = user.user_name

    if current_user == user
      @active_menu = :dashboard
      @active_dashboard_menu = :profile
    end

    user
  end
end
