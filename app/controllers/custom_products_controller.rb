# frozen_string_literal: true

class CustomProductsController < ApplicationController
  include FriendlyFinder
  include ProfileVisibility

  before_action :authenticate_user!, except: [:show]
  before_action :set_menu, except: [:show]
  before_action :set_show_user, only: [:show]
  before_action :find_custom_product, only: [:show]

  def index
    page_title(CustomProduct.model_name.human.pluralize)

    @custom_products = current_user.custom_products
                                   .includes([:images_attachments])
                                   .includes([:sub_categories])
                                   .order(:name).map do |custom_product|
      CustomProductPresenter.new(custom_product)
    end
  end

  def show
    possession = @user.possessions.find_by(custom_product_id: @custom_product.id)
    @possession = CustomProductPossessionPresenter.new(possession) if possession
    @render_possession_details = @possession && (
      @possession.period_from || @possession.period_to || @possession.setup ||
      @possession.price_purchase || @possession.price_sale || @possession.purchase_condition ||
      @possession.gift?
    )

    @custom_product = CustomProductPresenter.new(@custom_product)

    @setups = current_user.setups if @user == current_user

    page_title(@custom_product.display_name)
  end

  def new
    @custom_product = CustomProduct.new
    @categories = Category.includes([:sub_categories])

    page_title(I18n.t('custom_product.new.heading'))
  end

  def edit
    @custom_product = current_user.custom_products.friendly.find(params[:id])
    return if performed?

    @categories = Category.includes([:sub_categories])

    page_title("#{t('edit')} #{@custom_product.name}")
  end

  def create
    @custom_product = current_user.custom_products.new custom_product_params

    if @custom_product.save
      possession = Possession.new(
        user: current_user,
        custom_product: @custom_product
      )
      possession.save

      flash[:notice] = I18n.t(
        'custom_product.messages.created',
        name: @custom_product.name
      )
      redirect_to user_custom_product_path(
        id: @custom_product.friendly_id,
        user_id: current_user.user_name.downcase
      )
    else
      @active_dashboard_menu = :custom_products
      @categories = Category.includes([:sub_categories])
      render :new, status: :unprocessable_content
    end
  end

  def update
    @custom_product = current_user.custom_products.friendly.find(params[:id])
    @categories = Category.includes([:sub_categories])

    if @custom_product.update(custom_product_params)
      flash[:notice] = I18n.t(
        'custom_product.messages.updated',
        link: ActionController::Base.helpers.link_to(
          @custom_product.name,
          user_custom_product_path(
            id: @custom_product.friendly_id,
            user_id: current_user.user_name.downcase
          )
        )
      )

      params[:delete_image]&.each do |image_id|
        image = @custom_product.images.find(image_id)
        image.purge
      end

      redirect_to URI.parse(
        user_custom_product_url(
          user_id: @custom_product.user.user_name.downcase,
          id: @custom_product.friendly_id
        )
      ).path
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @custom_product = current_user.custom_products.friendly.find(params[:id])
    @custom_product.destroy
    flash[:notice] = I18n.t('custom_product.messages.deleted', name: @custom_product.name)
    redirect_to dashboard_custom_products_path
  end

  private

  def set_menu
    @active_dashboard_menu = :custom_products
    @active_menu = :dashboard
  end

  def set_show_user
    @user = find_viewable_user!(params[:user_id])
  end

  def find_custom_product
    @custom_product = find_resource(
      @user.custom_products, :id,
      path_helper: lambda do |custom_product|
        user_custom_product_path(id: custom_product.friendly_id, user_id: @user.lowercase_user_name)
      end
    )
  end

  def custom_product_params
    custom_product = params[:custom_product]

    if params[:delete_image]&.include?(custom_product[:highlighted_image_id])
      custom_product[:highlighted_image_id] = nil
    end

    params.expect(custom_product: [:name, :description, :highlighted_image_id, { sub_category_ids: [], images: [] }])
  end
end
