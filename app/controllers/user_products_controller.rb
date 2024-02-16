class UserProductsController < ApplicationController
  before_action :authenticate_user!

  def create
    @product = Product.find(params[:id])

    unless current_user.products.include?(@product)
      current_user.products << @product
      flash[:alert] = I18n.t(:generic_error_message) unless current_user.save
    end

    redirect_back fallback_location: root_url
  end

  def destroy
    @product = Product.find(params[:id])
    setup_with_product = current_user.setups.select { |setup| setup.products.include?(@product) }.first
    setup_with_product&.products&.delete(@product)
    current_user.products.delete(@product)
    redirect_back fallback_location: root_url
  end
end
