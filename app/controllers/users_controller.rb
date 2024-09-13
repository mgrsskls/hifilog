class UsersController < ApplicationController
  before_action :set_breadcrumb, except: [:show, :prev_owneds, :history]

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

    get_possessions

    @reset_path = @user.profile_path
    @render_since = true
    @render_period = false

    render 'show'
  end

  def prev_owneds
    @user = setup_user_page
    return unless @user

    get_possessions(prev_owned: true)

    @reset_path = user_previous_products_path(id: @user.user_name)
    @render_since = false
    @render_period = true

    render 'show'
  end

  def history
    @user = setup_user_page
    return unless @user

    possessions = @user.possessions
                       .where.not(period_from: nil)
                       .or(@user.possessions.where.not(period_to: nil))
                       .includes([product: [:brand]])
                       .includes([product_variant: [product: [:brand]]])
                       .includes([:product_option, :custom_product])
                       .includes([image_attachment: [:blob]])

    from = possessions.reject { |possession| possession.period_from.nil? }.sort_by(&:period_from).map do |possession|
      presenter = if possession.custom_product_id
                    CustomProductPossessionPresenter.new(possession)
                  else
                    PossessionPresenter.new(possession)
                  end

      {
        date: presenter.period_from,
        type: :from,
        presenter:
      }
    end

    to = possessions.reject { |possession| possession.period_to.nil? }.sort_by(&:period_to).map do |possession|
      presenter = if possession.custom_product_id
                    CustomProductPossessionPresenter.new(possession)
                  else
                    PossessionPresenter.new(possession)
                  end

      {
        date: presenter.period_to,
        type: :to,
        presenter:
      }
    end

    @possessions = (from + to)
                   .sort_by { |possession| possession[:date] }
                   .group_by { |possession| possession[:date].year }
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

    data = PaperTrail::Version.where(whodunnit: user.id)
                              .select(:item_id)
                              .distinct
                              .group('item_type', 'event')
                              .count

    @products_created = get_data(data, 'Product', 'create')
    @products_edited = get_data(data, 'Product', 'update')
    @brands_created = get_data(data, 'Brand', 'create')
    @brands_edited = get_data(data, 'Brand', 'update')

    if current_user == user
      @active_menu = :dashboard
      @active_dashboard_menu = :profile
    end

    user
  end

  def get_possessions(prev_owned: false)
    if params[:setup]
      setup = @user.setups.find(params[:setup])
      all_possessions = setup.possessions
    else
      all_possessions = @user.possessions
    end

    all = map_possessions_to_presenter all_possessions.where(prev_owned:)
                                                      .includes([product: [{ sub_categories: :category }, :brand]])
                                                      .includes([product_variant: [:product]])
                                                      .includes([:product_option])
                                                      .includes([custom_product: [{ sub_categories: :category }]])
                                                      .includes([image_attachment: [:blob]])

    all = all.sort_by { |possession| possession.display_name.downcase }

    if params[:category].present?
      @sub_category = SubCategory.friendly.find(params[:category])
      @possessions = all.select do |possession|
        @sub_category.products.include?(possession.product) ||
          @sub_category.custom_products.include?(possession.custom_product)
      end
    else
      @possessions = all
    end

    @categories = all.flat_map(&:sub_categories)
                     .sort_by(&:name)
                     .uniq
                     .group_by(&:category)
                     .sort_by { |category| category[0].order }
                     .map do |c|
                       [
                         c[0],
                         c[1].map do |sub_category|
                           {
                             name: sub_category.name,
                             friendly_id: sub_category.friendly_id,
                           }
                         end
                       ]
                     end
  end
end
