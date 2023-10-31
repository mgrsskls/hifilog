class SetupProductsController < ApplicationController
  before_action :authenticate_user!

  def create
    if params[:product_id] && params[:setup_id]
      @product = Product.find(params[:product_id])
      @setup = Setup.find(params[:setup_id])
      @setup.products << @product
      @setup.save
      redirect_to request.referer
    else
      destroy
    end
  end

  def destroy
    @product = Product.find(params[:product_id])
    @setup = Setup.find(params[:setup_id])
    @setup.products.delete(@product)
    redirect_to request.referer
  end
end
