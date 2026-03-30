# frozen_string_literal: true

class UsersController < ApplicationController
  include HistoryHelper
  include Possessions
  include ActionView::Helpers::SanitizeHelper

  def index
    page_title(User.model_name.human(count: 2))
    @meta_desc = 'See all users of hifilog.com with public profiles and how much they contributed. ' \
                 'HiFi Log is a user-driven database for hi-fi products and brands.'
    @users_by_products = User
                         .joins('INNER JOIN "versions" ON "versions"."whodunnit" = CAST("users"."id" AS varchar)')
                         .includes(:avatar_attachment)
                         .select('
                           users.id,
                           users.user_name,
                           users.profile_visibility,
                           users.created_at,
                           COUNT(DISTINCT versions.item_id) as count
                         ')
                         .group('users.id, users.user_name, users.profile_visibility, users.created_at')
                         .order(count: :desc)
  end

  def show
    @user = setup_user_page
    return unless @user

    @setup = @user.setups.find(params[:setup]) if params[:setup]
    possessions = @setup ? @setup.possessions : @user.possessions.where(prev_owned: false)

    all = PossessionPresenterService.map_to_presenters(get_possessions_for_user(possessions:))
    @sub_category = SubCategory.friendly.find(params[:category]) if params[:category].present?
    @possessions = if @sub_category
                     all.select { |p| p.sub_categories.include?(@sub_category) }
                   else
                     all
                   end
    @categories = get_grouped_sub_categories(possessions: all)
    @empty_state = 'public_profile'

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

    all = PossessionPresenterService.map_to_presenters(
      get_possessions_for_user(possessions: @user.possessions.where(prev_owned: true))
    )
    @sub_category = SubCategory.friendly.find(params[:category]) if params[:category].present?
    @possessions = if @sub_category
                     all.select { |p| p.sub_categories.include?(@sub_category) }
                   else
                     all
                   end
    @categories = get_grouped_sub_categories(possessions: all)
    @empty_state = 'public_profile_previous'

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

  def setup_user_page
    user = User.find_by('lower(user_name) = ?', (params[:user_id].presence || params[:id]).downcase)

    if user.nil? || (user.hidden? && current_user != user) || (user.logged_in_only? && !user_signed_in?)
      render 'not_found', status: :not_found
      return nil
    end

    user_name = sanitize(user.user_name)
    page_title(user_name)
    @meta_desc = "The public profile of #{user_name} on hifilog.com — check out their hi-fi gear! " \
                 'HiFi Log is a user-driven database for hi-fi products and brands.'

    @active_dashboard_menu = :profile if current_user == user

    user
  end
end
