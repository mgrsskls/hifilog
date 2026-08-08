# frozen_string_literal: true

class Dashboard::BookmarksController < ApplicationController
  include Bookmarks

  before_action :authenticate_user!
  before_action :set_menu

  def index
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

    @categories = grouped_sub_categories(bookmarks: all_bookmarks.reject do |bookmark|
      %w[Event Brand].include? bookmark.item_type
    end)

    @bookmark_list_options = bookmark_list_dialog_presenters
  end

  private

  def set_menu
    @active_menu = :dashboard
  end

  # Presenters for the "add bookmarks to this list" dialog. BookmarkPresenter touches
  # +bookmark.item+ (and +item.product+ for variants) in its constructor, so without
  # preloading this is two N+1s over every bookmark the user has. The +item+ association is
  # polymorphic, so nested associations are preloaded per concrete type instead of via
  # +includes+ (Brand / Event do not respond to +brand+ / +product+).
  def bookmark_list_dialog_presenters
    return [] if @bookmark_list.blank?

    bookmarks = current_user.bookmarks.includes(:bookmark_list, :item).to_a
    items = bookmarks.filter_map(&:item)

    preload_records(items.grep(Product), :brand)
    preload_records(items.grep(ProductVariant), product: :brand)

    bookmarks.map { |bookmark| BookmarkPresenter.new(bookmark) }
  end

  def preload_records(records, *associations)
    return if records.empty?

    ActiveRecord::Associations::Preloader.new(records:, associations:).call
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
end
