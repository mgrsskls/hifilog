class ApplicationController < ActionController::Base
  # before_action :block_bots
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::RoutingError, with: :not_found

  helper_method :current_user,
                :products_count,
                :brands_count,
                :categories_count,
                :newest_brands,
                :newest_products,
                :menu_categories

  def index
    redirect_to dashboard_root_path if user_signed_in?
  end

  attr_writer :current_user

  def menu_categories
    Rails.cache.fetch('/menu_categories') do
      Category.includes(:sub_categories).order(:order).group_by(&:column)
    end
  end

  def products_count
    Rails.cache.fetch('/product_count') do
      Product.count
    end
  end

  def brands_count
    Rails.cache.fetch('/brands_count') do
      Brand.count
    end
  end

  def categories_count
    Rails.cache.fetch('/categories_count') do
      SubCategory.count
    end
  end

  def newest_products
    Rails.cache.fetch('/newest_products') do
      products = Product.includes([:brand]).order(created_at: :desc).limit(10)
      product_variants = ProductVariant.includes([product: [:brand]]).order(created_at: :desc).limit(10)

      (products + product_variants).sort_by(&:created_at).reverse.take(10)
    end
  end

  def newest_brands
    Rails.cache.fetch('/newest_brands') do
      Brand.order(created_at: :desc).limit(10).to_a
    end
  end

  def after_sign_in_path_for(user)
    if user.instance_of?(AdminUser)
      admin_root_path
    elsif request.parameters[:redirect]
      request.parameters[:redirect]
    else
      stored_location_for(user) || dashboard_root_path
    end
  end

  def not_found
    if action_name == 'changelog' || controller_path.split('/').first == 'admin'
      render
    else
      render 'not_found', status: :not_found
    end
  end

  private

  def block_bots
    head :forbidden if BOTS.any? do |user_agent|
      request.user_agent.downcase.include?(user_agent.downcase) if request.user_agent.present?
    end
  end

  def redirect_back_to_product(product: nil, product_variant: nil, custom_product: nil)
    if custom_product.present?
      return redirect_back fallback_location: user_custom_product_url(
        user_id: current_user.user_name.downcase,
        id: custom_product.id
      )
    end

    if product_variant.present?
      return redirect_back fallback_location: product_variant_url(
        id: product_variant.friendly_id,
        product_id: product_variant.product.friendly_id
      )
    end

    redirect_back fallback_location: product_url(id: product.friendly_id)
  end

  def map_possessions_to_presenter(possessions)
    possessions.map do |possession|
      if possession.custom_product_id
        CustomProductPossessionPresenter.new(possession)
      elsif possession.prev_owned
        PreviousPossessionPresenter.new(possession)
      else
        CurrentPossessionPresenter.new(possession)
      end
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:user_name])
    devise_parameter_sanitizer.permit(
      :account_update,
      keys: [:profile_visibility, :user_name, :avatar, :decorative_image, :receives_newsletter]
    )
  end
end
