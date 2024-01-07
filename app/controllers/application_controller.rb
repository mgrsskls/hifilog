class ApplicationController < ActionController::Base
    before_action :configure_permitted_parameters, if: :devise_controller?

    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    helper_method :current_user
    helper_method :user_has_product?
    helper_method :user_has_brand?
    helper_method :user_has_bookmark?

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
        if user.class == AdminUser
            admin_root_path
        elsif request.parameters[:redirect]
            request.parameters[:redirect]
        else
            dashboard_products_path
        end
    end

    def user_has_product?(product)
        return if !product
        user_signed_in? && current_user.products.include?(product)
    end

    def user_has_bookmark?(product)
        return if !product
        user_signed_in? && Bookmark.where(product_id: product.id, user_id: current_user.id).any?
    end

    def user_has_brand?(brand)
        return if !brand
        user_signed_in? && current_user.products.select { |p| p.brand_id == brand.id }.any?
    end

    def content_not_found
      render file: "#{Rails.root}/public/404.html", layout: true, status: :not_found
    end

    protected

    def configure_permitted_parameters
        devise_parameter_sanitizer.permit(:account_update, keys: [:profile_visibility, :user_name])
    end

    def record_not_found
      render "404", layout: true, status: :not_found
    end
end
