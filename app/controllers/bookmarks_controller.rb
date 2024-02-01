class BookmarksController < ApplicationController
  before_action :authenticate_user!

  def create
    @product = Product.find(params[:id])

    @bookmark = current_user.bookmarks.new(product: @product)
    @bookmark.save

    redirect_to brand_product_path(id: @product.friendly_id, brand_id: @product.brand.friendly_id)
  end

  def destroy
    @bookmark = current_user.bookmarks.find_by(id: params[:id])&.destroy!

    redirect_back fallback_location: root_url
  end
end
