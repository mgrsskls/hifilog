class ApplicationController < ActionController::Base
    before_action :configure_permitted_parameters, if: :devise_controller?

    helper_method :current_user
    helper_method :user_has_product?
    helper_method :user_has_brand?

    def index
        @products = Product.all
        @brands = Brand.all
        @categories = SubCategory.all

        @newest_products = @products.order(created_at: :desc).limit(10)
        @newest_brands = @brands.order(created_at: :desc).limit(10)
    end

    def current_user=(user)
        @current_user = user
    end

    def after_sign_in_path_for(user)
        dashboard_root_path
    end

    def user_has_product?(product)
        return if !product
        user_signed_in? && current_user.products.include?(product)
    end

    def user_has_brand?(brand)
        return if !brand
        user_signed_in? && current_user.products.select { |p| p.brand_id == brand.id }.any?
    end

    protected

    def configure_permitted_parameters
        devise_parameter_sanitizer.permit(:account_update, keys: [:profile_visibility])
    end
end
