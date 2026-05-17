# frozen_string_literal: true

class PossessionsController < ApplicationController
  include ApplicationHelper
  include Possessions

  before_action :authenticate_user!

  def current
    @active_menu = :dashboard
    page_title(I18n.t('headings.collection'))
    @active_dashboard_menu = :products

    all = PossessionPresenterService.map_to_presenters(
      get_possessions_for_user(possessions: current_user.possessions.where(prev_owned: false))
    )

    category = params[:category]
    @sub_category = SubCategory.friendly.find(category) if category.present?
    @possessions = if @sub_category
                     all.select { |possession| possession.sub_categories.include?(@sub_category) }
                   else
                     all
                   end
    @categories = get_grouped_sub_categories(possessions: all)
  end

  def previous
    @active_menu = :dashboard
    page_title(I18n.t('headings.prev_owneds'))
    @active_dashboard_menu = :prev_owneds

    all = PossessionPresenterService.map_to_presenters(
      get_possessions_for_user(possessions: current_user.possessions.where(prev_owned: true))
    )

    category = params[:category]
    @sub_category = SubCategory.friendly.find(category) if category.present?
    @possessions = if @sub_category
                     all.select { |possession| possession.sub_categories.include?(@sub_category) }
                   else
                     all
                   end
    @categories = get_grouped_sub_categories(possessions: all)
  end

  def create
    id = params[:id]
    product_variant_id = params[:product_variant_id]
    custom_product_id = params[:custom_product_id]

    @product = Product.find(id) if id.present?
    @product_variant = ProductVariant.find(product_variant_id) if product_variant_id.present?
    @custom_product = CustomProduct.find(custom_product_id) if custom_product_id.present?

    @active_possession = Possession.new(
      user: current_user,
      product: @product || nil,
      product_variant: @product_variant || nil,
      custom_product: @custom_product || nil,
      prev_owned: params[:prev_owned] == 'true'
    )
    flash[:alert] = I18n.t(:generic_error_message) unless @active_possession.save

    redirect_back_to_product(
      product: @product,
      product_variant: @product_variant,
      custom_product: @custom_product
    )
  end

  def update
    @possession = current_user.possessions.find(params[:id])

    setup_id = params[:setup_id]
    if setup_id
      setup = current_user.setups.find(setup_id) if setup_id.present?

      @possession.setup = setup

      show_errors unless @possession.save
    end

    if @possession.update(possession_params)
      @possession.purge_images_by_id!(params[:delete_image])
    else
      show_errors
    end

    redirect_back_to_product(
      product: @possession.product,
      product_variant: @possession.product_variant,
      custom_product: @possession.custom_product
    )
  end

  def destroy
    possession = current_user.possessions.find(params[:id])
    is_prev_owned = possession.prev_owned?
    product = possession.product
    product_variant = possession.product_variant
    custom_product = possession.custom_product

    possession_presenter = possession.custom_product_id ? CustomProductPossessionPresenter : PossessionPresenter
    presenter = possession_presenter.new(possession)

    if possession&.destroy
      name = presenter.display_name
      flash[:notice] = if is_prev_owned
                         I18n.t('possession.messages.removed_from_prev', name:)
                       else
                         I18n.t('possession.messages.removed', name:)
                       end
    else
      flash[:alert] = I18n.t(:generic_error_message)
    end

    redirect_back_to_product(
      product:,
      product_variant:,
      custom_product:
    )
  end

  def move_to_prev_owneds
    possession = current_user.possessions.find(params[:possession_id])
    unless possession.prev_owned?
      possession.prev_owned = true
      possession.setup = nil
      possession.moved_to_previous_at = Time.current
    end

    product = possession.product
    product_variant = possession.product_variant
    custom_product = possession.custom_product

    possession_presenter = custom_product.present? ? CustomProductPossessionPresenter : PreviousPossessionPresenter
    presenter = possession_presenter.new(possession)

    if possession.save
      flash[:notice] = I18n.t(
        'possession.messages.moved_to_prev',
        name: presenter.display_name
      )
    else
      flash[:alert] = I18n.t(:generic_error_message)
    end

    if (path = safe_redirect_path(params[:redirect_to]))
      return redirect_to path
    end

    redirect_back_to_product(
      product:,
      product_variant:,
      custom_product:
    )
  end

  private

  def possession_params
    possession = params[:possession]
    return ActionController::Parameters.new({}).permit! unless possession

    possession[:highlighted_image_id] = nil if params[:delete_image]&.include?(possession[:highlighted_image_id])
    if possession.key?(:purchase_condition)
      raw = possession[:purchase_condition]
      key = raw.to_s.strip
      if key.blank?
        possession[:purchase_condition] = nil
      elsif !Possession.purchase_conditions.key?(key)
        possession.delete(:purchase_condition)
      end
    end

    possession.permit(:period_from, :period_to, :product_option_id, :highlighted_image_id, :gift, :price_purchase,
                      :price_purchase_currency, :price_sale, :price_sale_currency, :purchase_condition,
                      images: [])
  end

  def show_errors
    @possession.errors.full_messages.each do |error|
      flash.now[:alert] = error
    end
  end
end
