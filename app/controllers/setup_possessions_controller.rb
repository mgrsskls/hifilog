class SetupPossessionsController < ApplicationController
  before_action :authenticate_user!

  def create
    if params[:possession_id] && params[:setup_id]
      possession = current_user.possessions.find(params[:possession_id])
      setup = current_user.setups.find(params[:setup_id])
      setup.possessions << possession
      flash[:alert] = I18n.t(:generic_error_message) unless setup.save
      redirect_back fallback_location: root_url
    else
      destroy
    end
  end

  def destroy
    current_user.setup_possessions.find(params[:id])&.destroy

    redirect_back fallback_location: root_url
  end
end
