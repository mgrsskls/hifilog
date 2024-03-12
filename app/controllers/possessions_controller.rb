class PossessionsController < ApplicationController
  include ApplicationHelper

  before_action :authenticate_user!

  def create
    @product = Product.find(params[:id])
    @variant = ProductVariant.find(params[:product_variant_id]) if params[:product_variant_id].present?

    possession = Possession.new(user: current_user, product: @product, product_variant: @variant || nil)
    flash[:alert] = I18n.t(:generic_error_message) unless possession.save

    redirect_back fallback_location: root_url
  end

  def destroy
    current_user.possessions.find(params[:id])&.destroy

    redirect_back fallback_location: root_url
  end
end
