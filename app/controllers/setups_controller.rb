class SetupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_breadcrumb

  def index
    @page_title = I18n.t('headings.setups')
    @setups = current_user.setups.order('LOWER(name)')
  end

  def show
    @setup = current_user.setups.find(params[:id])

    add_breadcrumb @setup.name, dashboard_setup_path(@setup)
    @page_title = @setup.name

    all_possessions = @setup.possessions
                            .joins(:product)
                            .includes([product: [{ sub_categories: :category }, :brand]])
                            .map { |possession| SetupItemPresenter.new(possession, @setup) }

    all_custom_products = @setup.possessions.joins(:custom_product)
                                .includes([custom_product: [{ sub_categories: :category }]])
                                .map { |possession| CustomProductPresenter.new(possession) }

    all = (all_possessions + all_custom_products).sort_by { |p| p.short_name.downcase }

    if params[:category].present?
      @sub_category = SubCategory.friendly.find(params[:category])
      @possessions = all.select do |possession|
        @sub_category.products.include?(possession.product) ||
          @sub_category.custom_products.include?(possession.custom_product)
      end
    else
      @possessions = all
    end

    @categories = all_possessions.map(&:product)
                                 .flat_map(&:sub_categories)
                                 .sort_by(&:name)
                                 .uniq
                                 .group_by(&:category)
                                 .sort_by { |category| category[0].order }
                                 # rubocop:disable Style/BlockDelimiters
                                 .map { |c|
                                   [
                                     c[0],
                                     c[1].map { |sub_category|
                                       # rubocop:enable Style/BlockDelimiters
                                       {
                                         name: sub_category.name,
                                         friendly_id: sub_category.friendly_id,
                                         path: dashboard_setup_path(id: @setup.id, category: sub_category.friendly_id)
                                       }
                                     }
                                   ]
                                 }
    @reset_path = dashboard_setup_path(@setup)
  end

  def new
    @setup = Setup.new

    add_breadcrumb I18n.t('new_setup.heading')
  end

  def create
    @setup = Setup.new(setup_params)

    if @setup.save && current_user.setups << @setup
      flash[:notice] = I18n.t(
        'setups.created',
        link: ActionController::Base.helpers.link_to(@setup.name, dashboard_setup_path(@setup))
      )
      redirect_to dashboard_setups_path
    else
      @active_dashboard_menu = :setups
      @setups = current_user.setups.order('LOWER(name)')
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @setup = current_user.setups.find(params[:id])

    add_breadcrumb @setup.name, dashboard_setup_path(id: @setup.id)
    add_breadcrumb I18n.t('edit')
  end

  def update
    @setup = current_user.setups.find(params[:id])
    @active_dashboard_menu = :setups

    possessions_in_other_setups = current_user.setup_possessions
                                              .where.not(setup_id: @setup.id)
                                              .where(possession_id: setup_params[:possession_ids])

    if possessions_in_other_setups.update(setup_id: @setup.id) && @setup.update(setup_params)
      flash[:notice] = I18n.t(
        'setups.updated',
        name: @setup.name
      )
      redirect_to dashboard_setup_path(@setup)
    else
      render :edit, status: :unprocessable_entity
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
    params.require(:setup).permit(:name, :private, possession_ids: [])
  end
end
