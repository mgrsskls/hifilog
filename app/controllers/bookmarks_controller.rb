class BookmarksController < ApplicationController
  before_action :authenticate_user!

  def create
    @product = Product.find(params[:id])

    @bookmark = Bookmark.new(product_id: @product.id, user_id: current_user.id)
    @bookmark.save

    redirect_to brand_product_path(id: @product.friendly_id, brand_id: @product.brand.friendly_id)
  end

  def destroy
    @bookmark = Bookmark.find(params[:id]).destroy!

    redirect_back fallback_location: root_url
  end
end
