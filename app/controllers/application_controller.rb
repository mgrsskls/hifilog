# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ApplicationHelper

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_footer_data
  after_action :record_page_view

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::RoutingError, with: :not_found

  helper_method :current_user,
                :products_count,
                :brands_count,
                :categories_count,
                :newest_brands,
                :newest_products,
                :menu_categories

  def page_title(title, meta_description = nil)
    @page_title = title
    @meta_desc = meta_description.presence
  end

  def index
    redirect_to dashboard_root_path if user_signed_in?

    @brand_countries = Brand
                       .group(:country_code)
                       .order('COUNT(country_code) DESC')
                       .limit(5)
                       .count
                       .map do |country|
      country_code = country[0]
      {
        label: country_name_from_country_code(country_code),
        brands_path: brands_path({ brands: { country: country_code } }),
        products_path: products_path({ brands: { country: country_code } })
      }
    end
  end

  def record_page_view
    user_agent = request.user_agent

    return if user_agent.blank?
    return if BLOCKED_AGENTS.any? { |agent| user_agent.include?(agent) }
    return unless response&.content_type&.start_with?('text/html')
    return if request.is_crawler?
    return if current_user&.id == 1
    return if request.path.start_with?('/admin')
    return if request.ip.present? && IPS_BLOCKED_FOR_ANALYTICS.any? { |ip| request.ip.start_with?(ip) }

    ActiveAnalytics.record_request(request)
  end

  def menu_categories
    CacheService.menu_categories
  end

  def products_count
    CacheService.products_count
  end

  def brands_count
    CacheService.brands_count
  end

  def categories_count
    CacheService.categories_count
  end

  def newest_products
    CacheService.newest_products
  end

  def newest_brands
    CacheService.newest_brands
  end

  def after_sign_in_path_for(user)
    redirect_param = request.parameters[:redirect]

    if user.instance_of?(AdminUser)
      admin_root_path
    elsif redirect_param
      redirect_param
    else
      stored_location_for(user) || dashboard_root_path
    end
  end

  def not_found
    if action_name == 'changelog' || controller_path.split('/').first == 'admin'
      render
    else
      respond_to do |format|
        format.all  { render 'application/not_found', status: :not_found, formats: [:html] }
      end
    end
  end

  private

  def set_footer_data
    @newest_products = newest_products
    @newest_brands = newest_brands
  end

  def redirect_back_to_product(product: nil, product_variant: nil, custom_product: nil)
    if custom_product.present?
      return redirect_back_or_to user_custom_product_url(
        user_id: current_user.user_name.downcase,
        id: custom_product.id
      )
    end

    if product_variant.present?
      return redirect_back_or_to product_variant_url(
        id: product_variant.friendly_id,
        product_id: product_variant.product.friendly_id
      )
    end

    redirect_back_or_to product_url(id: product.friendly_id)
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
