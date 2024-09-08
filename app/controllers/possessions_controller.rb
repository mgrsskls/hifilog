class PossessionsController < ApplicationController
  include ApplicationHelper

  before_action :authenticate_user!

  def previous
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
    add_breadcrumb I18n.t('headings.prev_owneds'), dashboard_prev_owneds_path
    @page_title = I18n.t('headings.prev_owneds')
    @active_dashboard_menu = :prev_owneds

    all = map_possessions_to_presenter current_user.possessions
                                                   .where(prev_owned: true)
                                                   .includes([product: [{ sub_categories: :category }, :brand]])
                                                   .includes([:product_variant])
                                                   .includes([custom_product: [{ sub_categories: :category }]])
                                                   .includes([image_attachment: [:blob]])

    all = all.sort_by { |possession| possession.display_name.downcase }

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
                             path: dashboard_products_path(category: sub_category.friendly_id)
                           }
                         end
                       ]
                     end
    @reset_path = dashboard_prev_owneds_path
  end

  def create
    @product = Product.find(params[:id]) if params[:id].present?
    @product_variant = ProductVariant.find(params[:product_variant_id]) if params[:product_variant_id].present?
    @custom_product = CustomProduct.find(params[:custom_product_id]) if params[:custom_product_id].present?

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
      custom_product: @custom_product,
    )
  end

  def update
    @possession = current_user.possessions.find(params[:id])

    if params[:possession][:delete_image].present? && params[:possession][:delete_image].to_i == 1
      @possession.image.purge
      @possession.save
      return redirect_back fallback_location: root_url
    end

    if params[:setup_id]
      setup = current_user.setups.find(params[:setup_id]) if params[:setup_id].present?

      @possession.setup = setup

      unless @possession.save
        @possession.errors.full_messages.each do |error|
          flash.now[:alert] = error
        end
      end
    end

    unless @possession.update(possession_params)
      @possession.errors.full_messages.each do |error|
        flash[:alert] = error
      end
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
      flash[:notice] = if is_prev_owned
                         I18n.t('possession.messages.removed_from_prev', name: presenter.display_name)
                       else
                         I18n.t('possession.messages.removed', name: presenter.display_name)
                       end
    else
      flash[:alert] = I18n.t(:generic_error_message)
    end

    redirect_back_to_product(
      product:,
      product_variant:,
      custom_product:,
    )
  end

  def move_to_prev_owneds
    possession = current_user.possessions.find(params[:possession_id])
    possession.update(prev_owned: true, setup: nil)

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

    return redirect_to params[:redirect_to] if params[:redirect_to]

    redirect_back_to_product(
      product:,
      product_variant:,
      custom_product:,
    )
  end

  private

  def possession_params
    params.require(:possession).permit(:image, :period_from, :period_to, :product_option_id)
  end
end
