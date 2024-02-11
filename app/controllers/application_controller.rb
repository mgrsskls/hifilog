require 'redcarpet'

class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::RoutingError, with: :not_found

  helper_method :current_user,
                :products_count,
                :brands_count,
                :categories_count,
                :newest_brands,
                :newest_products

  def index
    redirect_to dashboard_root_path if user_signed_in?
  end

  attr_writer :current_user

  def products_count
    @products_count ||= Product.all.count
  end

  def brands_count
    @brands_count ||= Brand.all.count
  end

  def categories_count
    @categories_count ||= SubCategory.all.count
  end

  def newest_products
    @newest_products ||= Product.includes([:brand]).limit(10).order(created_at: :desc)
  end

  def newest_brands
    @newest_brands ||= Brand.limit(10).order(created_at: :desc)
  end

  def after_sign_in_path_for(user)
    if user.instance_of?(AdminUser)
      admin_root_path
    elsif request.parameters[:redirect]
      request.parameters[:redirect]
    else
      dashboard_root_path
    end
  end

  def not_found
    if action_name == 'changelog' || controller_path.split('/').first == 'admin'
      render
    else
      render 'not_found', status: :not_found
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:user_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:profile_visibility, :user_name])
  end
end
