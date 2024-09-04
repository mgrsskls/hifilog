class SetupPossessionsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    setup_possession = current_user.setup_possessions.find(params[:id])

    return if setup_possession.blank?

    possession = setup_possession.possession
    product = possession.product
    product_variant = possession.product_variant
    custom_product = possession.custom_product

    possession.destroy

    if custom_product.present?
      return redirect_back fallback_location: user_custom_product_url(
        user_id: current_user.user_name.downcase,
        id: custom_product.id
      )
    end

    if product_variant.present?
      return redirect_back fallback_location: product_product_variant_url(
        variant: product_variant.friendly_id,
        product_id: product_variant.friendly_id
      )
    end

    redirect_back fallback_location: product_url(id: product.friendly_id)
  end
end
