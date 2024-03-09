class PossessionsController < ApplicationController
  include ApplicationHelper

  before_action :authenticate_user!

  def create
    @product = Product.find(params[:id])
    @variant = ProductVariant.find(params[:product_variant_id]) if params[:product_variant_id].present?

    user_has_product = user_has_product?(current_user, @product.id, @variant ? @variant.id : nil)

    unless user_has_product
      possession = Possession.new(user: current_user, product: @product, product_variant: @variant || nil)
      flash[:alert] = I18n.t(:generic_error_message) unless possession.save
    end

    redirect_back fallback_location: root_url
  end

  def destroy
    current_user.possessions.find(params[:id])&.destroy

    redirect_back fallback_location: root_url
  end
end
