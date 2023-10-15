class UserProductsController < ApplicationController
  before_action :authenticate_user!

  def create
    @product = Product.find(params[:id])
    current_user.products << @product
    current_user.save
    redirect_to request.referer
  end

  def destroy
    @product = Product.find(params[:id])
    current_user.products.delete(@product)
    redirect_to request.referer
  end
end