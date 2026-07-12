# frozen_string_literal: true

class UserController < ApplicationController
  include ApplicationHelper
  include Contributions
  include CurrentStatisticsOverview
  include HistoryHelper
  include Bookmarks

  FEED_PAGE_SIZE = 50

  before_action :authenticate_user!, except: [:newsletter_unsubscribe, :follow_notification_unsubscribe]
  skip_before_action :verify_authenticity_token, only: [:newsletter_unsubscribe, :follow_notification_unsubscribe]
  before_action :set_menu

  def dashboard
    page_title(I18n.t('dashboard'))
    @active_dashboard_menu = :dashboard

    @feed = UserActivityTimeline.grouped_for_following(current_user, time_zone: Time.zone, limit: 10)

    @newest_users = newest_users

    load_current_statistics_overview

    @events = current_user.events.upcoming.order(start_date: :asc).limit(2).to_a
    @event_attendee_counts = EventAttendee.counts_for(@events.map(&:id))

    @app_news = AppNews.where('created_at > ?', current_user.created_at)
                       .where.not(id: current_user.app_news_ids)
                       .order(:created_at)
                       .reverse
  end

  def feed
    page_title(I18n.t('headings.feed'))
    @active_dashboard_menu = :feed

    feed_page = UserActivityTimeline.paginated_for_following(
      current_user, time_zone: Time.zone, page: params[:page], per: FEED_PAGE_SIZE
    )
    @feed = feed_page.rows
    @feed_pagination = feed_page.activities
  end

  def bookmarks
    page_title(Bookmark.model_name.human.pluralize)

    all_bookmarks = current_user.bookmarks
                                .includes({ item: [{ sub_categories: [:category] }, :brand] })

    id = params[:id]
    if id.present?
      @bookmark_list = current_user.bookmark_lists.find(id)
      all_bookmarks = all_bookmarks.where(bookmark_list_id: id) if @bookmark_list.present?
      @active_dashboard_menu = "bookmark_list_#{id}"
    else
      @active_dashboard_menu = :bookmarks
    end

    all_product_bookmarks = all_bookmarks.where(item_type: %w[Product ProductVariant])
    all_brand_bookmarks = all_bookmarks.where(item_type: 'Brand')
    all_event_bookmarks = all_bookmarks.where(item_type: 'Event')

    @active_bookmarks = :all

    @all_bookmarks_count = all_bookmarks.size
    @products_bookmarks_count = all_product_bookmarks.size
    @brands_bookmarks_count = all_brand_bookmarks.size
    @events_bookmarks_count = all_event_bookmarks.size

    type = params[:type]
    if type.present? && %w[products brands events].include?(type)
      case type
      when 'products'
        all_bookmarks = all_product_bookmarks
        @active_bookmarks = :products
      when 'brands'
        all_bookmarks = all_brand_bookmarks
        @active_bookmarks = :brands
      when 'events'
        all_bookmarks = all_event_bookmarks
        @active_bookmarks = :events
      end
    end

    sort = case params[:sort]
           when 'added_asc' then 'created_at ASC'
           else 'created_at DESC'
           end

    all_bookmarks = all_bookmarks
                    .order(sort)
                    .map { |bookmark| BookmarkPresenter.new(bookmark) }

    bookmarks = all_bookmarks

    category = params[:category]
    if category.present?
      sub_cat = SubCategory.friendly.find(category)

      if sub_cat
        bookmarks =
          bookmarks.select do |bookmark|
            %w[Product ProductVariant].include?(bookmark.item_type) && bookmark.product.sub_categories.include?(sub_cat)
          end
        @sub_category = sub_cat
      end
    end

    @bookmarks = bookmarks
    event_ids = @bookmarks.filter_map { |b| b.item_id if b.item_type == 'Event' }.uniq
    @event_attendee_counts = EventAttendee.counts_for(event_ids)

    assign_bookmark_product_items_for_thumbnails!(@bookmarks)

    @categories = get_grouped_sub_categories(bookmarks: all_bookmarks.reject do |bookmark|
      %w[Event Brand].include? bookmark.item_type
    end)
  end

  def events
    page_title(Event.model_name.human.pluralize)
    @active_dashboard_menu = :events
    @active_events = :upcoming

    user_events = current_user.events

    all_events = user_events.upcoming
    get_events(all_events:, order: :asc)
    @all_upcoming_events_count = all_events.size
    today = Time.zone.today
    @all_past_events_count = user_events
                             .where(end_date: ..today)
                             .or(Event.where(start_date: ..today, end_date: nil))
                             .size
    @empty_state_message = I18n.t('event_attendee.empty_states.user.upcoming', path: events_path)
  end

  def past_events
    page_title("Past #{Event.model_name.human.pluralize}")
    @active_dashboard_menu = :events
    @active_events = :past

    today = Time.zone.today

    user_events = current_user.events

    all_events = user_events.where(end_date: ..today)
                            .or(Event.where(start_date: ..today, end_date: nil))
    get_events(all_events:, order: :desc)
    @all_upcoming_events_count = user_events.upcoming.size
    @all_past_events_count = all_events.size
    @empty_state_message = I18n.t('event_attendee.empty_states.user.past', path: past_events_path)

    render 'events'
  end

  def contributions
    page_title(I18n.t('headings.contributions'))
    @active_dashboard_menu = :contributions

    whodunnit = current_user.id

    products = Product.joins(:versions)
                      .distinct
                      .includes([:brand])
                      .select('products.*, versions.event')
                      .where(versions: { item_type: 'Product', whodunnit: })
    product_variants = ProductVariant.joins(:versions)
                                     .distinct
                                     .includes([{ product: [:brand] }])
                                     .select('product_variants.*, versions.event')
                                     .where(versions: { item_type: 'ProductVariant', whodunnit: })
    @items = (products + product_variants)
             .sort_by { |possession| possession.display_name.downcase }
             .group_by(&:event)
    @brands = Brand.joins(:versions)
                   .distinct
                   .select('brands.*, versions.event')
                   .where(versions: { item_type: 'Brand', whodunnit: })
                   .order(:name)
                   .group_by(&:event)
  end

  def history
    page_title(I18n.t('headings.history'))
    @active_dashboard_menu = :history
    @possessions = get_history_possessions(current_user.possessions)
  end

  def following
    setup_community_section(active_tab: :following)
    page_title(I18n.t('headings.following'))
    @user_follows = current_user.user_follows
                                .includes(:followed)
                                .joins(:followed)
                                .order(Arel.sql('LOWER(users.user_name) ASC'))
  end

  def followers
    setup_community_section(active_tab: :followers)
    page_title(I18n.t('headings.followers'))
    @follower_relationships = current_user.follower_relationships
                                          .includes(follower: { avatar_attachment: :blob })
                                          .joins(:follower)
                                          .order(Arel.sql('LOWER(users.user_name) ASC'))
  end

  def blocked
    page_title(I18n.t('headings.blocked'))
    @active_dashboard_menu = :blocked
    @user_blocks = current_user.user_blocks
                               .includes(blocked: { avatar_attachment: :blob })
                               .joins(:blocked)
                               .order(Arel.sql('LOWER(users.user_name) ASC'))
  end

  def has
    # 1. Load bookmarks into a Set of strings like "Brand:5" or "Product:12"
    # This makes lookups O(1) instead of searching the array every time!
    bookmark_keys = current_user.bookmarks.pluck(:item_type, :item_id).to_set { |type, id| "#{type}:#{id}" }

    param_brands = params[:brands]
    param_products = params[:products]
    params_product_variants = params[:product_variants]
    param_events = params[:events]

    # Initialize empty arrays so the render doesn't break if params are missing
    brands = products = product_variants = events = []

    # --- BRANDS ---
    if param_brands.present?
      brand_ids = param_brands.map(&:to_i)

      # Pluck only the IDs we need to know ownership state!
      # Returns an array of tuples: [[brand_id, prev_owned_boolean], ...]
      poss_data = current_user.possessions
                              .joins(:product)
                              .where(products: { brand_id: brand_ids })
                              .pluck('products.brand_id', :prev_owned)

      brands = brand_ids.map do |brand_id|
        {
          id: brand_id,
          in_collection: poss_data.any? { |b_id, prev| b_id == brand_id && !prev },
          previously_owned: poss_data.any? { |b_id, prev| b_id == brand_id && prev },
          bookmarked: bookmark_keys.include?("Brand:#{brand_id}")
        }
      end
    end

    # --- PRODUCTS ---
    if param_products.present?
      product_ids = param_products.map(&:to_i)

      poss_data = current_user.possessions
                              .where(product_id: product_ids, product_variant_id: nil)
                              .pluck(:product_id, :prev_owned)

      products = product_ids.map do |product_id|
        {
          id: product_id,
          in_collection: poss_data.any? { |p_id, prev| p_id == product_id && !prev },
          previously_owned: poss_data.any? { |p_id, prev| p_id == product_id && prev },
          bookmarked: bookmark_keys.include?("Product:#{product_id}")
        }
      end
    end

    # --- PRODUCT VARIANTS ---
    if params_product_variants.present?
      variant_ids = params_product_variants.map(&:to_i)

      poss_data = current_user.possessions
                              .where(product_variant_id: variant_ids)
                              .pluck(:product_variant_id, :prev_owned)

      product_variants = variant_ids.map do |variant_id|
        {
          id: variant_id,
          in_collection: poss_data.any? { |pv_id, prev| pv_id == variant_id && !prev },
          previously_owned: poss_data.any? { |pv_id, prev| pv_id == variant_id && prev },
          bookmarked: bookmark_keys.include?("ProductVariant:#{variant_id}")
        }
      end
    end

    # --- EVENTS ---
    if param_events.present?
      event_ids = param_events.map(&:to_i)

      attendee_data = current_user.event_attendees
                                  .joins(:event)
                                  .where(event_id: event_ids)
                                  .pluck(:event_id, :end_date)

      events = param_events
               .map do |event_id|
        event_id = event_id.to_i
        {
          id: event_id,
          in_collection: attendee_data.any? do |event|
            event[0] == event_id && !event[1].past?
          end,
          previously_owned: attendee_data.any? do |event|
            event[0] == event_id && event[1].past?
          end,
          bookmarked: bookmark_keys.include?("Event:#{event_id}")
        }
      end
    end

    render json: { brands:, products:, product_variants:, events: }
  end

  def counts
    render json: {
      products: user_possessions_count(user: current_user, prev_owned: false),
      custom_products: user_custom_products_count(current_user),
      previous_products: user_possessions_count(user: current_user, prev_owned: true),
      setups: user_setups_count(current_user),
      bookmarks: user_bookmarks_count(current_user),
      events: user_events_count(current_user),
      notes: user_notes_count(current_user)
    }
  end

  def newsletter_unsubscribe
    return head :bad_request if request.post? && !one_click_unsubscribe_request?

    user = newsletter_unsubscribe_user

    if user
      user.update(receives_newsletter: false)
      respond_to_newsletter_unsubscribe(:success)
    else
      respond_to_newsletter_unsubscribe(:invalid)
    end
  end

  def follow_notification_unsubscribe
    return head :bad_request if request.post? && !one_click_unsubscribe_request?

    user = follow_notification_unsubscribe_user

    if user
      user.update(receives_follow_notifications: false)
      respond_to_follow_notification_unsubscribe(:success)
    else
      respond_to_follow_notification_unsubscribe(:invalid)
    end
  end

  private

  def newsletter_unsubscribe_user
    hash_param = params[:hash].presence || request.query_parameters['hash'].presence
    NewsletterUnsubscribeService.decode_token(hash_param)
  end

  def follow_notification_unsubscribe_user
    hash_param = params[:hash].presence || request.query_parameters['hash'].presence
    FollowNotificationUnsubscribeService.decode_token(hash_param)
  end

  def respond_to_newsletter_unsubscribe(result)
    if request.post?
      return head :bad_request if result == :invalid

      head :ok
    elsif result == :success
      redirect_to root_path, notice: I18n.t('newsletter.messages.unsubscribed')
    else
      redirect_to root_path, alert: I18n.t('newsletter.messages.invalid_unsubscribe_link')
    end
  end

  def respond_to_follow_notification_unsubscribe(result)
    if request.post?
      return head :bad_request if result == :invalid

      head :ok
    elsif result == :success
      redirect_to root_path, notice: I18n.t('user_follow.notifications.unsubscribed')
    else
      redirect_to root_path, alert: I18n.t('user_follow.notifications.invalid_unsubscribe_link')
    end
  end

  def one_click_unsubscribe_request?
    params['List-Unsubscribe'] == 'One-Click'
  end

  def assign_bookmark_product_items_for_thumbnails!(bookmark_presenters)
    @bookmark_product_items = {}

    product_ids = bookmark_presenters.select { |b| b.item_type == 'Product' }.map { |b| b.product.id }.uniq
    variant_ids = bookmark_presenters.select { |b| b.item_type == 'ProductVariant' }
                                     .map { |b| b.product_variant.id }
                                     .uniq
    return if product_ids.empty? && variant_ids.empty?

    relation = ProductItem.none
    relation = relation.or(ProductItem.where(item_type: 'Product', product_id: product_ids)) if product_ids.any?
    if variant_ids.any?
      relation = relation.or(ProductItem.where(item_type: 'ProductVariant', product_variant_id: variant_ids))
    end

    ProductItem.preload_list_possession_images(relation).each do |pi|
      key = pi.item_type == 'ProductVariant' ? [:variant, pi.product_variant_id] : [:product, pi.product_id]
      @bookmark_product_items[key] = pi
    end
  end

  def get_events(all_events: [], order: :asc)
    country_code = params[:country]
    scoped = country_code.present? ? all_events.where(country_code:) : all_events
    @events = scoped.order(start_date: order).to_a
    ids = @events.map(&:id)
    @event_attendee_counts = EventAttendee.counts_for(ids)
    @years = @events.group_by { |event| event.start_date.year }
                    .transform_values do |events_in_year|
                      events_in_year.group_by { |event| event.start_date.month }
                    end
    @country_codes = all_events.map(&:country_code).uniq.sort
  end

  def setup_community_section(active_tab:)
    @active_dashboard_menu = :community
    @active_community_tab = active_tab
    @following_count = current_user.user_follows.count
    @followers_count = current_user.follower_relationships.count
  end

  def set_menu
    @active_menu = :dashboard
  end

  def in_collection?(possession_id, prev_owned, id)
    possession_id == id && !prev_owned
  end

  def previously_owned?(possession_id, prev_owned, id)
    possession_id == id && prev_owned
  end
end
