class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  helper_method :current_user
  helper_method :user_has_product?
  helper_method :user_has_brand?
  helper_method :user_has_bookmark?
  helper_method :all_records
  helper_method :newest_products
  helper_method :newest_brands

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
      user_products_path(id: user.id)
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
    return unless user_signed_in?

    current_user.products.where(brand_id: brand.id).any?
  end

  def content_not_found
    render file: Rails.root.join('public/404.html').to_s, layout: true, status: :not_found
  end

  def not_found
    record_not_found
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
      Product.find_each do |product|
        m.add brand_product_path(
          id: product.friendly_id,
          brand_id: product.brand.friendly_id
        ), updated: product.updated_at
      end

      SubCategory.find_each do |sub_category|
        m.add category_sub_category_path(id: sub_category.friendly_id, category_id: sub_category.category.friendly_id)
      end
    end

    render xml: map.render
  end

  def feed
    products = Product.all
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

  def record_not_found
    render '404', layout: true, status: :not_found
  end
end
