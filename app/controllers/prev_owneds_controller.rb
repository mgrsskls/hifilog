class PrevOwnedsController < ApplicationController
  before_action :authenticate_user!

  def create
    @product = Product.find(params[:product_id])
    @variant = ProductVariant.find(params[:product_variant_id]) if params[:product_variant_id].present?

    @bookmark = current_user.prev_owneds.new(
      product: @product,
      product_variant: @variant || nil
    )

    flash[:alert] = I18n.t(:generic_error_message) unless @bookmark.save

    redirect_back fallback_location: root_url
  end

  def destroy
    @prev_owned = current_user.prev_owneds.find(params[:id])&.destroy

    redirect_back fallback_location: root_url
  end
end
