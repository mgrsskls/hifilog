# frozen_string_literal: true

class BookmarksController < ApplicationController
  # Checked in this order: a request only ever carries one of these ids.
  BOOKMARKABLE_PARAMS = {
    product_variant_id: ProductVariant,
    product_id: Product,
    event_id: Event,
    brand_id: Brand
  }.freeze

  before_action :authenticate_user!

  def create
    item = find_bookmarkable_item
    assign_bookmarkable_item(item)

    @bookmark = current_user.bookmarks.new(item_id: item.id, item_type: item.class.name) if item
    flash[:alert] = I18n.t(:generic_error_message) unless @bookmark.save

    if @brand.present?
      redirect_to brand_path(id: @brand.friendly_id)
    elsif @event.present?
      redirect_to event_path(year: @event.calendar_year, slug: @event.friendly_id)
    else
      redirect_back_to_product(
        product: @product,
        product_variant: @product_variant
      )
    end
  end

  def update
    bookmark = current_user.bookmarks.find(params[:id])
    list = current_user.bookmark_lists.find(params[:bookmark_list_id]) if params[:bookmark_list_id].present?

    if list
      bookmark.update(bookmark_list_id: list.id)
    else
      bookmark.update(bookmark_list_id: nil)
    end

    redirect_to_safe_path(params[:redirect_to], fallback: dashboard_bookmarks_path)
  end

  def destroy
    bookmark = current_user.bookmarks.find(params[:id])
    presenter = BookmarkPresenter.new(bookmark)

    if bookmark&.destroy
      flash[:notice] = I18n.t(
        'bookmark.messages.removed',
        name: presenter.display_name
      )
    end

    redirect_to_safe_path(params[:redirect_to], fallback: dashboard_bookmarks_path)
  end

  private

  def find_bookmarkable_item
    BOOKMARKABLE_PARAMS.each do |param_key, model_class|
      id = params[param_key]
      return model_class.find(id) if id.present?
    end

    nil
  end

  def assign_bookmarkable_item(item)
    case item
    when ProductVariant then @product_variant = item
    when Product then @product = item
    when Event then @event = item
    when Brand then @brand = item
    end
  end
end
