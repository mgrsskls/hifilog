class PossessionsController < ApplicationController
  include ApplicationHelper

  before_action :authenticate_user!

  def previous
    add_breadcrumb I18n.t('headings.prev_owneds'), dashboard_prev_owneds_path
    @page_title = I18n.t('headings.prev_owneds')
    @active_dashboard_menu = :prev_owneds

    all = current_user.possessions
                      .where(prev_owned: true)
                      .includes([product: [{ sub_categories: :category }, :brand]])
                      .includes([:product_variant])
                      .includes([custom_product: [{ sub_categories: :category }]])
                      .includes([image_attachment: [:blob]])
                      .map do |possession|
                        if possession.custom_product_id
                          CustomProductPossessionPresenter.new(possession)
                        else
                          PreviousPossessionPresenter.new(possession)
                        end
                      end
                      .sort_by(&:display_name)

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
    @variant = ProductVariant.find(params[:product_variant_id]) if params[:product_variant_id].present?
    @custom_product = CustomProduct.find(params[:custom_product_id]) if params[:custom_product_id].present?

    possession = Possession.new(
      user: current_user,
      product: @product || nil,
      product_variant: @variant || nil,
      custom_product: @custom_product || nil,
      prev_owned: params[:prev_owned] == 'true'
    )
    flash[:alert] = I18n.t(:generic_error_message) unless possession.save

    redirect_back fallback_location: root_url
  end

  def destroy
    possession = current_user.possessions.find(params[:id])
    is_prev_owned = possession.prev_owned?

    possession_presenter = possession.custom_product_id ? CustomProductPossessionPresenter : PossessionPresenter
    presenter = possession_presenter.new(possession)

    if possession&.destroy
      flash[:notice] = if is_prev_owned
                         "Your <b>#{presenter.display_name}</b> has been removed from your list of previous products."
                       else
                         "Your <b>#{presenter.display_name}</b> has been removed from your collection."
                       end
    else
      flash[:alert] = I18n.t(:generic_error_message)
    end

    redirect_back fallback_location: root_url
  end

  def update
    @possession = current_user.possessions.find(params[:id])

    return redirect_back fallback_location: root_url unless params[:possession]

    if params[:possession][:delete_image].present? && params[:possession][:delete_image].to_i == 1
      @possession.image.purge
      @possession.save
    elsif params[:possession][:setup_id]
      setup = current_user.setups.find(params[:possession][:setup_id]) if params[:possession][:setup_id].present?

      @possession.setup = setup

      unless @possession.save
        @possession.errors.full_messages.each do |error|
          flash[:alert] = error
        end
      end
    elsif !@possession.update(possession_params)
      @possession.errors.full_messages.each do |error|
        flash[:alert] = error
      end
    end

    redirect_back fallback_location: root_url
  end

  def move_to_prev_owneds
    possession = current_user.possessions.find(params[:possession_id])
    possession.update(prev_owned: true, setup: nil)

    possession_presenter = possession.custom_product_id ? CustomProductPossessionPresenter : PreviousPossessionPresenter
    presenter = possession_presenter.new(possession)

    if possession.save
      flash[:notice] = "
        Your <b>#{presenter.display_name}</b> has been moved
        to your list of <a href=\"#{dashboard_prev_owneds_path}\">previous products</a>.
      "
    else
      flash[:alert] = I18n.t(:generic_error_message)
    end

    if params[:redirect_to]
      redirect_to params[:redirect_to]
    else
      redirect_back fallback_location: root_url
    end
  end

  private

  def possession_params
    params.require(:possession).permit(:image)
  end
end
