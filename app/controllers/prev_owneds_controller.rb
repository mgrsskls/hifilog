class PrevOwnedsController < ApplicationController
  before_action :authenticate_user!

  def create
    @product = Product.find(params[:id])

    @prev_owned = current_user.prev_owneds.new(product: @product)

    flash[:alert] = I18n.t(:generic_error_message) unless @prev_owned.save

    redirect_to product_path(id: @product.friendly_id)
  end

  def destroy
    @prev_owned = current_user.prev_owneds.find_by(id: params[:id])&.destroy

    redirect_back fallback_location: root_url
  end
end
