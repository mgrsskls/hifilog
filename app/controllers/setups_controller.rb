class SetupsController < ApplicationController
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

    @all_possessions = current_user.possessions
                                   .includes([product: [{ sub_categories: :category }, :brand]])
                                   .includes(
                                     [
                                       product_variant: [
                                         product: [
                                           { sub_categories: :category },
                                           :brand
                                         ]
                                       ]
                                     ]
                                   )
                                   .includes(
                                     [
                                       custom_product:
                                        [
                                          { sub_categories: :category, },
                                          :user,
                                          { image_attachment: :blob }
                                        ]
                                     ]
                                   )
                                   .includes([{ image_attachment: :blob }])
                                   .includes([:product_option])
                                   .includes([:setup_possession])
                                   .includes([:setup])
                                   .order(
                                     [
                                       'brand.name',
                                       'product.name',
                                       'product_variant.name',
                                       'custom_product.name'
                                     ]
                                   )
                                   .map do |possession|
                                     if possession.custom_product
                                       CustomProductSetupPossessionPresenter.new(possession, @setup)
                                     else
                                       SetupPossessionPresenter.new(possession, @setup)
                                     end
                                   end

    all = @all_possessions.select { |possession| possession.setup == @setup }

    if params[:category].present?
      @sub_category = SubCategory.friendly.find(params[:category])
      @possessions = all.select do |possession|
        @sub_category.products.include?(possession.product) ||
          @sub_category.custom_products.include?(possession.custom_product)
      end
    else
      @possessions = all
    end

    @categories = all.flat_map(&:sub_categories)
                     .sort_by(&:name)
                     .uniq
                     .group_by(&:category)
                     .sort_by { |category| category[0].order }
                     .map do |c|
                       [
                         c[0],
                         c[1].map do |sub_category|
                           {
                             name: sub_category.name,
                             friendly_id: sub_category.friendly_id,
                             path: dashboard_setup_path(id: @setup.id, category: sub_category.friendly_id)
                           }
                         end
                       ]
                     end
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
    params.require(:setup).permit(:name, :private, possession_ids: [])
  end
end
