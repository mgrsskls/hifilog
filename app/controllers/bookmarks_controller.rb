class BookmarksController < ApplicationController
  before_action :authenticate_user!

  def create
    @product_variant = ProductVariant.find(params[:product_variant_id]) if params[:product_variant_id].present?

    if @product_variant.present?
      @product = @product_variant.product
      @bookmark = current_user.bookmarks.new(
        product_variant: @product_variant,
        product: @product
      )
    else
      @product = Product.find(params[:product_id])
      @bookmark = current_user.bookmarks.new(
        product: @product
      )
    end

    flash[:alert] = I18n.t(:generic_error_message) unless @bookmark.save

    redirect_back_to_product(
      product: @product,
      product_variant: @product_variant,
    )
  end

  def destroy
    bookmark = current_user.bookmarks.find(params[:id])
    presenter = BookmarkPresenter.new(bookmark)
    product = bookmark.product
    product_variant = bookmark.product_variant

    if bookmark&.destroy
      flash[:notice] = I18n.t(
        'bookmark.messages.removed',
        name: presenter.display_name
      )
    end

    redirect_back_to_product(
      product:,
      product_variant:,
    )
  end
end
