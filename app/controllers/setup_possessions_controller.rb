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

    redirect_back_to_product(product:, product_variant:, custom_product:)
  end
end
