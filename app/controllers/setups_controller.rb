# frozen_string_literal: true

class SetupsController < ApplicationController
  include Possessions
  include FriendlyFinder

  before_action :authenticate_user!
  before_action :set_menu

  def index
    page_title(Setup.model_name.human.pluralize)
    @setups = current_user.setups.includes([:possessions]).order('LOWER(name)')
  end

  def show
    @setup = current_user.setups.friendly.find(params[:id])

    page_title(@setup.name)

    @all_possessions = PossessionPresenterService.map_to_presenters(
      current_user
        .possessions.where(prev_owned: false)
        .includes([{ product: [:brand] }])
        .includes([{ product_variant: [{ product: [:brand] }] }])
        .includes([{ custom_product: [{ images_attachments: :blob }] }])
        .includes([{ images_attachments: :blob }])
        .order(
          [
            'brand.name',
            'product.name',
            'product_variant.name',
            'custom_product.name'
          ]
        )
    )

    all = get_possessions_for_user(possessions: @setup.possessions).map do |possession|
      if possession.custom_product
        CustomProductSetupPossessionPresenter.new(possession, @setup)
      else
        SetupPossessionPresenter.new(possession, @setup)
      end
    end

    category = params[:category]
    @sub_category = SubCategory.friendly.find(category) if category.present?
    @possessions = if @sub_category
                     all.select { |possession| possession.sub_categories.include?(@sub_category) }
                   else
                     all
                   end
    @categories = get_grouped_sub_categories(possessions: all)
  end

  def new
    @setup = Setup.new(private: true)

    page_title(I18n.t('setup.new.heading'))
  end

  def edit
    @setup = current_user.setups.friendly.find(params[:id])
    return if performed?

    page_title("#{t('edit')} #{@setup.name}")
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
      render :new, status: :unprocessable_content
    end
  end

  def update
    @setup = current_user.setups.friendly.find(params[:id])
    @active_dashboard_menu = :setups

    update_params = setup_params.except(:possession_ids)
    success = if possession_ids_submitted?
                sync_setup_possessions(update_params)
              else
                @setup.update(update_params)
              end

    if success
      flash[:notice] = I18n.t(
        'setup.messages.updated',
        name: @setup.name
      )
      redirect_to dashboard_setups_path
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @setup = current_user.setups.friendly.find(params[:id])
    @setup.destroy
    flash[:notice] = I18n.t('setup.messages.deleted', name: @setup.name)
    redirect_to dashboard_setups_path
  end

  private

  def set_menu
    @active_dashboard_menu = :setups
    @active_menu = :dashboard
  end

  def setup_params
    params.expect(setup: [:name, :private, { possession_ids: [] }])
  end

  def possession_ids_submitted?
    setup = params[:setup]
    return false unless setup

    setup.key?(:possession_ids) || setup.key?('possession_ids')
  end

  def permitted_possession_ids
    ids = Array(setup_params[:possession_ids]).map(&:to_i).reject(&:zero?)
    current_user.possessions.where(id: ids).pluck(:id)
  end

  def sync_setup_possessions(update_params)
    setup_id = @setup.id
    permitted_ids = permitted_possession_ids
    possessions_in_other_setups = current_user.setup_possessions
                                              .where.not(setup_id:)
                                              .where(possession_id: permitted_ids)

    possessions_in_other_setups.update(setup_id:) &&
      @setup.update(update_params.merge(possession_ids: permitted_ids))
  end
end
