class ApplicationController < ActionController::Base
    helper_method :current_user
    helper_method :user_has_product?
    helper_method :user_has_brand?

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
end
