# frozen_string_literal: true

class UsersController < ApplicationController
  include HistoryHelper
  include Possessions
  include Contributions
  include CurrentStatisticsOverview
  include FriendlyFinder

  helper UserActivityHelper

  def index
    page_title(User.model_name.human.pluralize)
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

    @categories = []
    @sub_category = nil

    @activity_rows = UserActivityTimeline.grouped_for(@user, time_zone: Time.zone, public_profile_feed: true)
    @user_follow = current_user&.user_follows&.find_by(followed: @user) if user_signed_in? && current_user != @user

    load_current_statistics_overview(@user)

    @events = @user.events.upcoming.order(start_date: :asc).to_a
    @event_attendee_counts = EventAttendee.counts_for(@events.map(&:id))
    @collection = load_collection_preview(@user, limit: 6)

    @heading = I18n.t('headings.overview')
    page_title("#{@user.user_name} — #{@heading}")
  end

  def collection
    @user = setup_user_page
    return unless @user

    if params[:setup].present?
      @setup = @user.setups.where(private: false).friendly.find(params[:setup])

      if request.path != user_setup_path(setup: @setup.friendly_id, user_id: @user.lowercase_user_name)
        redirect_to URI.parse(user_setup_path(setup: @setup.friendly_id, user_id: @user.lowercase_user_name)).path,
                    status: :moved_permanently and return
      end
    end
    possessions = @setup.present? ? @setup.possessions : @user.possessions.where(prev_owned: false)

    all = PossessionPresenterService.map_to_presenters(possessions)

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

    render 'collection'
  end

  def history
    @user = setup_user_page
    return unless @user

    @possessions = get_history_possessions(@user.possessions)
    @heading = I18n.t('headings.history')
  end

  def activity
    user_name = (params[:user_id].presence || params[:id]).downcase
    redirect_to user_path(id: user_name), status: :moved_permanently
  end

  def contributions
    @user = setup_user_page
    return unless @user

    data = PaperTrail::Version.where(whodunnit: @user.id)
                              .select(:item_id)
                              .distinct
                              .group('item_type', 'event')
                              .count

    @products_created = version_group_count(data, 'Product', 'create')
    @products_edited = version_group_count(data, 'Product', 'update')
    @brands_created = version_group_count(data, 'Brand', 'create')
    @brands_edited = version_group_count(data, 'Brand', 'update')

    @heading = I18n.t('headings.contributions')
  end

  private

  def setup_user_page
    user = User.find_by('lower(user_name) = ?', (params[:user_id].presence || params[:id]).downcase)

    if user.nil? || (user.hidden? && current_user != user) || (user.logged_in_only? && !user_signed_in?)
      render 'not_found', status: :not_found
      return nil
    end

    page_title(ERB::Util.html_escape(user.user_name))
    @meta_desc = "The public profile of #{user.user_name} on hifilog.com — check out their hi-fi gear! " \
                 'HiFi Log is a user-driven database for hi-fi products and brands.'

    @active_dashboard_menu = :profile if current_user == user

    user
  end
end
