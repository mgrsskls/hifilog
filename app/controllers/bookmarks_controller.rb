class BookmarksController < ApplicationController
  before_action :authenticate_user!

  def create
    if params[:product_variant_id].present?
      @product_variant = ProductVariant.find(params[:product_variant_id])
    elsif params[:product_id].present?
      @product = Product.find(params[:product_id])
    elsif params[:event_id].present?
      @event = Event.find(params[:event_id])
    elsif params[:brand_id].present?
      @brand = Brand.find(params[:brand_id])
    end

    if @product_variant.present?
      @bookmark = current_user.bookmarks.new(
        item_id: @product_variant.id,
        item_type: 'ProductVariant'
      )
    elsif @product.present?
      @bookmark = current_user.bookmarks.new(
        item_id: @product.id,
        item_type: 'Product'
      )
    elsif @event.present?
      @bookmark = current_user.bookmarks.new(
        item_id: @event.id,
        item_type: 'Event'
      )
    elsif @brand.present?
      @bookmark = current_user.bookmarks.new(
        item_id: @brand.id,
        item_type: 'Brand'
      )
    end

    flash[:alert] = I18n.t(:generic_error_message) unless @bookmark.save

    if @brand.present?
      redirect_to brand_path(id: @brand.friendly_id)
    elsif @event.present?
      redirect_to events_path
    else
      redirect_back_to_product(
        product: @product,
        product_variant: @product_variant,
      )
    end
  end

  def update
    bookmark = current_user.bookmarks.find(params[:id])

    if params[:bookmark_list_id].present?
      bookmark.update(bookmark_list_id: params[:bookmark_list_id])
    else
      bookmark.update(bookmark_list_id: nil)
    end

    redirect_to params[:redirect_to] || dashboard_bookmarks_path
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

    redirect_to params[:redirect_to] || dashboard_bookmarks_path
  end
end
