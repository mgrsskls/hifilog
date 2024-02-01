class SetupsController < ApplicationController
  before_action :authenticate_user!

  def index
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
    add_breadcrumb I18n.t('headings.setups'), dashboard_setups_path
    @page_title = I18n.t('headings.setups')
    @active_dashboard_menu = :setups
    @setups = current_user.setups.order('LOWER(name)')
  end

  def show
    @active_dashboard_menu = :setups
    @setup = current_user.setups.find(params[:id])

    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
    add_breadcrumb I18n.t('headings.setups'), dashboard_setups_path
    add_breadcrumb @setup.name, dashboard_setup_path(@setup)
    @page_title = @setup.name
  end

  def create
    @setup = Setup.new(setup_params)

    if @setup.save
      current_user.setups << @setup
      flash[:notice] = I18n.t(
        'setups.created',
        link: ActionController::Base.helpers.link_to(@setup.name, dashboard_setup_path(@setup))
      )
      redirect_to dashboard_setups_path
    else
      @active_dashboard_menu = :setups
      @setups = current_user.setups.order('LOWER(name)')
      flash[:alert] = 'An error occured. Please try again.'
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @setup = current_user.setups.find(params[:id])
    @setup.destroy
    flash[:notice] = I18n.t('setups.deleted', name: @setup.name)
    redirect_to dashboard_setups_path
  end

  private

  def setup_params
    params.require(:setup).permit(:name)
  end
end
