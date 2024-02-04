class ProductsController < ApplicationController
  before_action :authenticate_user!, only: [:create]

  add_breadcrumb I18n.t('headings.products'), :products_path

  def index
    @active_menu = :products
    @page_title = I18n.t('headings.products')

    if params[:letter]
      add_breadcrumb params[:letter].upcase
      all_products = Product.where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
                            .includes([:brand, :sub_categories])
    else
      all_products = Product.all.includes([:brand, :sub_categories])
    end

    @products = all_products.order('LOWER(name)').page(params[:page])
    @total_size = all_products.count
  end

  def show
    @active_menu = :products

    @brand = Brand.friendly.find(params[:brand_id])
    @product = @brand.products.friendly.find(params[:id])

    if user_signed_in?
      @bookmark = current_user.bookmarks.find_by(product_id: @product.id)
      @setups = current_user.setups.includes(:products)
    end

    add_breadcrumb @product.brand.name, brand_path(@product.brand)
    add_breadcrumb @product.name
    @page_title = "#{@product.brand.name} #{@product.name}"
  end

  def new
    @active_menu = :products
    @page_title = I18n.t('new_product.heading')

    add_breadcrumb t('add')

    @product = Product.new
    @brands = Brand.all.order('LOWER(name)')
    @categories = Category.ordered

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
      @categories = Category.ordered
      @brand = Brand.find(@product.brand_id) if @product.brand_id
      render :new, status: :unprocessable_entity
    end
  end

  private

  def product_params
    params.require(:product).permit(:name, :brand_id, :discontinued, sub_category_ids: [])
  end
end
