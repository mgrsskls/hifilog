class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  helper_method :current_user
  helper_method :user_has_product?
  helper_method :user_has_brand?
  helper_method :user_has_bookmark?
  helper_method :newest_products
  helper_method :newest_brands

  def index
    @products = Product.all
    @brands = Brand.all
    @categories = SubCategory.all
  end

  attr_writer :current_user

  def newest_products
    Product.all.order(created_at: :desc).limit(10)
  end

  def newest_brands
    Brand.all.order(created_at: :desc).limit(10)
  end

  def after_sign_in_path_for(_)
    if instance_of?(AdminUser)
      admin_root_path
    elsif request.parameters[:redirect]
      request.parameters[:redirect]
    else
      dashboard_products_path
    end
  end

  def user_has_product?(product)
    return unless product

    user_signed_in? && current_user.products.include?(product)
  end

  def user_has_bookmark?(product)
    return unless product

    user_signed_in? && Bookmark.where(product_id: product.id, user_id: current_user.id).any?
  end

  def user_has_brand?(brand)
    return unless brand

    user_signed_in? && current_user.products.select { |p| p.brand_id == brand.id }.any?
  end

  def content_not_found
    render file: Rails.root.join('public/404.html').to_s, layout: true, status: :not_found
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:user_name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[profile_visibility user_name])
  end

  def record_not_found
    render '404', layout: true, status: :not_found
  end
end
