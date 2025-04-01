class SetupsController < ApplicationController
  include Possessions

  before_action :authenticate_user!
  before_action :set_breadcrumb

  def index
    @page_title = Setup.model_name.human(count: 2)
    @setups = current_user.setups.includes([:possessions]).order('LOWER(name)')
  end

  def show
    @setup = current_user.setups.find(params[:id])

    add_breadcrumb @setup.name, dashboard_setup_path(@setup)
    @page_title = @setup.name

    @all_possessions = map_possessions_to_presenter current_user
                       .possessions.where(prev_owned: false)
                       .includes([product: [:brand]])
                       .includes([product_variant: [product: [:brand]]])
                       .includes([custom_product: [{ images_attachments: :blob }]])
                       .includes([{ images_attachments: :blob }])
                       .order(
                         [
                           'brand.name',
                           'product.name',
                           'product_variant.name',
                           'custom_product.name'
                         ]
                       )

    all = get_possessions_for_user(possessions: @setup.possessions).map do |possession|
      if possession.custom_product
        CustomProductSetupPossessionPresenter.new(possession, @setup)
      else
        SetupPossessionPresenter.new(possession, @setup)
      end
    end
    @sub_category = SubCategory.friendly.find(params[:category]) if params[:category].present?
    @possessions = if @sub_category
                     all.select { |p| p.sub_categories.include?(@sub_category) }
                   else
                     all
                   end
    @categories = get_grouped_sub_categories(possessions: all)
  end

  def new
    @setup = Setup.new(private: true)

    add_breadcrumb I18n.t('setup.new.heading')
  end

  def edit
    @setup = current_user.setups.find(params[:id])

    add_breadcrumb @setup.name, dashboard_setup_path(id: @setup.id)
    add_breadcrumb I18n.t('edit')
  end

  def create
    @setup = Setup.new(setup_params)
    @setup.user = current_user

    if @setup.save
      flash[:notice] = I18n.t(
        'setup.messages.created',
        link: ActionController::Base.helpers.link_to(@setup.name, dashboard_setup_path(@setup))
      )
      redirect_to dashboard_setups_path
    else
      @active_dashboard_menu = :setups
      @setups = current_user.setups.order('LOWER(name)')
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @setup = current_user.setups.find(params[:id])
    @active_dashboard_menu = :setups

    possessions_in_other_setups = current_user.setup_possessions
                                              .where.not(setup_id: @setup.id)
                                              .where(possession_id: setup_params[:possession_ids])

    if possessions_in_other_setups.update(setup_id: @setup.id) && @setup.update(setup_params)
      flash[:notice] = I18n.t(
        'setup.messages.updated',
        name: @setup.name
      )
      redirect_to dashboard_setups_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @setup = current_user.setups.find(params[:id])
    @setup.destroy
    flash[:notice] = I18n.t('setup.messages.deleted', name: @setup.name)
    redirect_to dashboard_setups_path
  end

  private

  def set_breadcrumb
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
    add_breadcrumb Setup.model_name.human(count: 2), dashboard_setups_path
    @active_dashboard_menu = :setups
    @active_menu = :dashboard
  end

  def setup_params
    params.expect(setup: [:name, :private, { possession_ids: [] }])
  end
end
