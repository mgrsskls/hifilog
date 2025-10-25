class BookmarksController < ApplicationController
  before_action :authenticate_user!

  def create
    @product_variant = ProductVariant.find(params[:product_variant_id]) if params[:product_variant_id].present?

    if @product_variant.present?
      @bookmark = current_user.bookmarks.new(
        item_id: @product_variant.id,
        item_type: 'ProductVariant'
      )
    else
      @product = Product.find(params[:product_id])

      if @product.present?
        @bookmark = current_user.bookmarks.new(
          item_id: @product.id,
          item_type: 'Product'
        )
      end
    end

    flash[:alert] = I18n.t(:generic_error_message) unless @bookmark.save

    redirect_back_to_product(
      product: @product,
      product_variant: @product_variant,
    )
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
