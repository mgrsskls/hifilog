class BookmarksController < ApplicationController
  before_action :authenticate_user!

  def create
    @product = Product.find(params[:product_id])
    @variant = ProductVariant.find(params[:product_variant_id]) if params[:product_variant_id].present?

    @bookmark = current_user.bookmarks.new(
      product: @product,
      product_variant: @variant || nil
    )

    flash[:alert] = I18n.t(:generic_error_message) unless @bookmark.save

    redirect_back fallback_location: root_url
  end

  def destroy
    @bookmark = current_user.bookmarks.find(params[:id])
    presenter = BookmarkPresenter.new(@bookmark)

    if @bookmark&.destroy
      flash[:notice] = I18n.t(
        'bookmark.messages.removed',
        name: presenter.display_name
      )
    end

    redirect_back fallback_location: root_url
  end
end
