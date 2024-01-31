require 'redcarpet'

class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::RoutingError, with: :not_found

  helper_method :current_user,
                :all_records,
                :newest_brands,
                :newest_products,
                :user_has_bookmark?,
                :user_has_brand?,
                :user_has_product?

  def index
    @is_home = true
  end

  attr_writer :current_user

  def all_records
    {
      products: Product.all.includes([:brand]),
      brands: Brand.all,
      categories: SubCategory.all,
    }
  end

  def newest_products
    all_records[:products].limit(10).order(created_at: :desc)
  end

  def newest_brands
    all_records[:brands].limit(10).order(created_at: :desc)
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

  def user_has_product?(product)
    product && user_signed_in? && current_user.products.where(id: product.id).exists?
  end

  def user_has_bookmark?(product)
    product && user_signed_in? && Bookmark.where(product_id: product.id, user_id: current_user.id).exists?
  end

  def user_has_brand?(brand)
    brand && user_signed_in? && current_user.products.where(brand_id: brand.id).exists?
  end

  def not_found
    render 'not_found', status: :not_found
  end

  def sitemap
    map = XmlSitemap::Map.new('www.hifilog.com', secure: true) do |m|
      m.add brands_path
      Brand.find_each do |brand|
        m.add brand_path(brand)
      end

      m.add categories_path
      Category.find_each do |category|
        m.add category_path(category)
      end

      m.add products_path
      Product.includes([:brand]).find_each do |product|
        m.add brand_product_path(
          id: product.friendly_id,
          brand_id: product.brand.friendly_id
        ), updated: product.updated_at
      end

      SubCategory.includes([:category]).find_each do |sub_category|
        m.add category_sub_category_path(id: sub_category.friendly_id, category_id: sub_category.category.friendly_id)
      end
    end

    render xml: map.render
  end

  def feed
    products = Product.all.includes([:brand])
    brands = Brand.all

    @all = (products + brands).sort_by(&:created_at)

    respond_to do |format|
      format.rss { render layout: false }
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:user_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:profile_visibility, :user_name])
  end
end
