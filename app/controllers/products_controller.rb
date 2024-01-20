class ProductsController < ApplicationController
  before_action :authenticate_user!, only: [:create]

  add_breadcrumb 'Hifi Gear', :root_path
  add_breadcrumb I18n.t('headings.products'), :products_path

  def index
    @active_menu = :products

    if params[:letter]
      add_breadcrumb params[:letter].upcase
      all_products = Product.where('name LIKE :prefix', prefix: "#{params[:letter]}%")
    else
      all_products = Product.all
    end

    @products = all_products.order('LOWER(name)').page(params[:page])
    @total_size = all_products.size
  end

  def show
    @active_menu = :products

    @brand = Brand.friendly.find(params[:brand_id])
    @product = @brand.products.friendly.find(params[:id])
    @user_has_product = user_signed_in? ? current_user.products.include?(@product) : false
    @setups = user_signed_in? ? current_user.setups.select { |setup| setup.products.include?(@product) } : []
    @bookmark = Bookmark.where(product_id: @product.id, user_id: current_user.id).first if user_signed_in?

    add_breadcrumb @product.brand.name, brand_path(@product.brand)
    add_breadcrumb @product.name
  end

  def new
    @active_menu = :products

    add_breadcrumb t('add')

    @product = Product.new
    @brands = Brand.all.order('LOWER(name)')
    @categories = Category.all

    return unless params[:brand_id]

    @product.brand_id = params[:brand_id]
    @brand = Brand.find(params[:brand_id])
  end

  def create
    @active_menu = :products
    @product = Product.new(product_params)

    if @product.save
      redirect_to brand_product_url(id: @product.friendly_id, brand_id: @product.brand.friendly_id)
    else
      @brands = Brand.all.order('LOWER(name)')
      @categories = Category.all
      @brand = Brand.find(@product.brand_id) if @product.brand_id
      render :new, status: :unprocessable_entity
    end
  end

  private

  def product_params
    params.require(:product).permit(:name, :brand_id, :discontinued, sub_category_ids: [])
  end
end
