class ProductsController < ApplicationController
  STATUSES = %w[discontinued continued].freeze

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:create]
  before_action :set_breadcrumb, only: [:show, :new, :edit, :changelog]

  def index
    @active_menu = :products
    @page_title = I18n.t('headings.products')

    if params[:letter].present? || params[:category].present? || params[:status].present?
      add_breadcrumb I18n.t('headings.products'), proc { :products }
    else
      add_breadcrumb I18n.t('headings.products')
    end

    if params[:letter].present? && params[:category].present? && params[:status].present?
      @category = Category.find(params[:category])
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb @category.name, products_path(letter: params[:letter], category: params[:category])
      add_breadcrumb I18n.t(params[:status])
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: { category_id: params[:category] })
                         .where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                         .where(
                           discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                         )
                         .includes([:brand, :sub_categories])
                         .order('LOWER(products.name)')
                         .page(params[:page])
    elsif params[:letter].present? && params[:category].present?
      @category = Category.find(params[:category])
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb @category.name
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: { category_id: params[:category] })
                         .where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                         .includes([:brand, :sub_categories])
                         .order('LOWER(products.name)')
                         .page(params[:page])
    elsif params[:letter].present? && params[:status].present?
      add_breadcrumb params[:letter].upcase, products_path(letter: params[:letter])
      add_breadcrumb I18n.t(params[:status])
      @products = Product.where('left(lower(products.name),1) = :prefix', prefix: params[:letter].downcase)
                         .where(
                           discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                         )
                         .includes([:brand, :sub_categories])
                         .order('LOWER(products.name)')
                         .page(params[:page])
    elsif params[:category].present? && params[:status].present?
      @category = Category.find(params[:category])
      add_breadcrumb @category.name, products_path(category: params[:category])
      add_breadcrumb I18n.t(params[:status])
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: { category_id: params[:category] })
                         .where(
                           discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil
                         )
                         .includes([:brand, :sub_categories])
                         .order('LOWER(products.name)')
                         .page(params[:page])
    elsif params[:letter].present?
      add_breadcrumb params[:letter].upcase
      @products = Product.where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
                         .includes([:brand, :sub_categories])
                         .order('LOWER(name)')
                         .page(params[:page])
    elsif params[:category].present?
      @category = Category.find(params[:category])
      add_breadcrumb @category.name
      @products = Product.joins(:sub_categories)
                         .where(sub_categories: { category_id: params[:category] })
                         .includes([:brand, :sub_categories])
                         .order('LOWER(products.name)')
                         .page(params[:page])
    elsif params[:status].present?
      add_breadcrumb I18n.t(params[:status])
      @products = Product.where(discontinued:
                           STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                         .includes([:brand, :sub_categories])
                         .order('LOWER(name)')
                         .page(params[:page])
    else
      @products = Product.all.includes([:brand, :sub_categories]).order('LOWER(name)').page(params[:page])
    end
  end

  def show
    @active_menu = :products

    @product = Product.friendly.find(params[:id])
    @brand = @product.brand

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

    @product = Product.new
    @brands = Brand.all.order('LOWER(name)')
    @categories = Category.ordered

    if params[:brand_id]
      @product.brand_id = params[:brand_id]
      @brand = Brand.find(params[:brand_id])

      add_breadcrumb @brand.name, brand_path(@brand)
    end

    add_breadcrumb t('add_product')
  end

  def create
    @active_menu = :products
    @product = Product.new(product_params)

    if @product.save
      redirect_to product_url(id: @product.friendly_id)
    else
      @brands = Brand.all.order('LOWER(name)')
      @categories = Category.ordered
      @brand = Brand.find(@product.brand_id) if @product.brand_id
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @active_menu = :products
    @page_title = I18n.t('new_product.heading')

    @product = Product.friendly.find(params[:id])
    @brand = @product.brand
    @brands = Brand.all.order('LOWER(name)')
    @categories = Category.ordered

    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb @product.name, product_path(id: @product.friendly_id)
    add_breadcrumb I18n.t('edit')
  end

  def update
    @active_menu = :products
    @product = Product.find(params[:id])

    if @product.update(product_update_params)
      redirect_to product_url(id: @product.friendly_id)
    else
      @brands = Brand.all.order('LOWER(name)')
      @categories = Category.ordered
      @brand = Brand.find(@product.brand_id)
      render :edit, status: :unprocessable_entity
    end
  end

  def changelog
    @product = Product.friendly.find(params[:product_id])
    @brand = @product.brand

    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb @product.name, product_path(id: @product.id)
    add_breadcrumb I18n.t('headings.changelog')
  end

  private

  def set_breadcrumb
    add_breadcrumb I18n.t('headings.products'), products_path
  end

  def product_params
    params.require(:product).permit(:name, :brand_id, :discontinued, sub_category_ids: [])
  end

  def product_update_params
    params.require(:product).permit(:name, :discontinued, sub_category_ids: [])
  end
end
