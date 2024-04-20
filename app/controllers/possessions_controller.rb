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

  def update
    @possession = Possession.find(params[:id])

    unless params[:possession] || params[:delete_image] || params[:setup_id]
      return redirect_back fallback_location: root_url
    end

    @possession.image.purge if params[:delete_image]

    unless params[:setup_id].nil?
      @possession.setup = params[:setup_id].blank? ? nil : current_user.setups.find(params[:setup_id])
      @possession.save
    end

    if params[:possession].present?
      if possession_params[:image]
        path = possession_params[:image].tempfile
        if ImageProcessing::MiniMagick.valid_image?(path)
          ImageProcessing::MiniMagick.source(path.path)
                                     .resize_to_fit(1200, 1200)
                                     .quality(80)
                                     .call(destination: path.path)
        end
      end

      unless @possession.update(possession_params)
        @possession.errors.full_messages.each do |error|
          flash[:alert] = error
        end
      end
    end

    redirect_back fallback_location: root_url
  end

  private

  def possession_params
    params.require(:possession).permit(:image)
  end
end
