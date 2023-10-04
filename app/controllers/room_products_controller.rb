class RoomProductsController < ApplicationController
  before_action :authenticate_user!

  def create
    if params[:product_id] && params[:room_id]
      @product = Product.find(params[:product_id])
      @room = Room.find(params[:room_id])
      @room.products << @product
      @room.save
      redirect_to request.referer
    else
      destroy
    end
  end

  def destroy
    @product = Product.find(params[:product_id])
    @room = Room.find(params[:room_id])
    @room.products.delete(@product)
    redirect_to request.referer
  end
end
