class SetupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_breadcrumb

  def index
    @page_title = I18n.t('headings.setups')
    @setups = current_user.setups.order('LOWER(name)')
  end

  def show
    @setup = current_user.setups.includes(products: [:sub_categories, :brand]).find(params[:id])

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
      flash[:alert] = I18n.t(:generic_error_message)
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

  def set_breadcrumb
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
    add_breadcrumb I18n.t('headings.setups'), dashboard_setups_path
    @active_dashboard_menu = :setups
    @active_menu = :dashboard
  end

  def setup_params
    params.require(:setup).permit(:name)
  end
end
