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

    if params[:delete_image]
      @possession.image.purge
      return redirect_back fallback_location: root_url
    end

    return unless params[:possession]

    path = possession_params[:image].tempfile
    if ImageProcessing::MiniMagick.valid_image?(path)
      ImageProcessing::MiniMagick.source(path.path)
                                 .resize_to_limit(1200, 1200)
                                 .quality(80)
                                 .convert('webp')
                                 .call(destination: path.path)
    end

    unless @possession.update(possession_params)
      @possession.errors.full_messages.each do |error|
        flash[:alert] = error
      end
    end

    redirect_back fallback_location: root_url
  end

  private

  def possession_params
    params.require(:possession).permit(:image)
  end
end
