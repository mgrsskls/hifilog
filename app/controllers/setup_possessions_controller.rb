class SetupPossessionsController < ApplicationController
  before_action :authenticate_user!

  def create
    possession = current_user.possessions.find(params[:possession_id])
    setup = current_user.setups.find(params[:setup_id])
    setup.possessions << possession
    flash[:alert] = I18n.t(:generic_error_message) unless setup.save
    redirect_back fallback_location: root_url
  end

  def update
    setup_possession = current_user.setup_possessions.find(params[:id])
    setup_possession.update(setup_possession_params)
    flash[:alert] = I18n.t(:generic_error_message) unless setup_possession.save
    redirect_back fallback_location: root_url
  end

  def destroy
    current_user.setup_possessions.find(params[:id])&.destroy

    redirect_back fallback_location: root_url
  end

  private

  def setup_possession_params
    params.require(:setup_possession).permit(:setup_id)
  end
end
