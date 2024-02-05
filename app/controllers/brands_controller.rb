class BrandsController < ApplicationController
  STATUSES = %w[discontinued continued].freeze

  before_action :authenticate_user!, only: [:create]

  def index
    @active_menu = :brands
    @page_title = I18n.t('headings.brands')

    if params[:letter].present? || params[:category].present? || params[:status].present?
      add_breadcrumb I18n.t('headings.brands'), proc { :brands }
    else
      add_breadcrumb I18n.t('headings.brands')
    end

    if params[:letter].present? && params[:category].present? && params[:status].present?
      @category = Category.find(params[:category])
      add_breadcrumb params[:letter].upcase, brands_path(letter: params[:letter])
      add_breadcrumb @category.name, brands_path(letter: params[:letter], category: params[:category])
      add_breadcrumb I18n.t(params[:status])
      @brands = Brand.joins(:products)
                     .where('left(lower(brands.name),1) = :prefix', prefix: params[:letter].downcase)
                     .where({ sub_categories: { category_id: params[:category] } })
                     .where(discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                     .includes(products: :sub_categories)
                     .order('LOWER(brands.name)')
                     .page(params[:page])
    elsif params[:letter].present? && params[:category].present?
      @category = Category.find(params[:category])
      add_breadcrumb params[:letter].upcase, brands_path(letter: params[:letter])
      add_breadcrumb @category.name
      @brands = Brand.joins(:products)
                     .where('left(lower(brands.name),1) = :prefix', prefix: params[:letter].downcase)
                     .where({ sub_categories: { category_id: params[:category] } })
                     .includes(products: :sub_categories)
                     .order('LOWER(brands.name)')
                     .page(params[:page])
    elsif params[:letter].present? && params[:status].present?
      add_breadcrumb params[:letter].upcase, brands_path(letter: params[:letter])
      add_breadcrumb I18n.t(params[:status])
      @brands = Brand.where('left(lower(brands.name),1) = :prefix', prefix: params[:letter].downcase)
                     .where(discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                     .includes(products: :sub_categories)
                     .order('LOWER(name)')
                     .page(params[:page])
    elsif params[:category].present? && params[:status].present?
      @category = Category.find(params[:category])
      add_breadcrumb @category.name, brands_path(category: params[:category])
      add_breadcrumb I18n.t(params[:status])
      @brands = Brand.joins(:products)
                     .where({ sub_categories: { category_id: params[:category] } })
                     .where(discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                     .includes(products: :sub_categories)
                     .order('LOWER(brands.name)')
                     .page(params[:page])
    elsif params[:letter].present?
      add_breadcrumb params[:letter].upcase
      @brands = Brand.where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
                     .includes(products: :sub_categories)
                     .order('LOWER(name)')
                     .page(params[:page])
    elsif params[:category].present?
      @category = Category.find(params[:category])
      add_breadcrumb @category.name
      @brands = Brand.joins(:products)
                     .where({ sub_categories: { category_id: params[:category] } })
                     .includes(products: :sub_categories)
                     .order('LOWER(brands.name)')
                     .page(params[:page])
    elsif params[:status].present?
      add_breadcrumb I18n.t(params[:status])
      @brands = Brand.where(discontinued: STATUSES.include?(params[:status]) ? params[:status] == 'discontinued' : nil)
                     .order('LOWER(brands.name)')
                     .page(params[:page])
    else
      @brands = Brand.all.includes(products: :sub_categories).order('LOWER(name)').page(params[:page])
    end
  end

  def show
    @active_menu = :brands

    @brand = Brand.friendly.find(params[:id])
    @products = @brand.products.includes([:sub_categories]).order('LOWER(name)').page(params[:page])

    add_breadcrumb I18n.t('headings.brands'), brands_path
    add_breadcrumb @brand.name
    @page_title = @brand.name
  end

  def category
    @active_menu = :brands

    sub_category = SubCategory.friendly.find(params[:category])
    @brand = Brand.friendly.find(params[:brand_id])
    @products = sub_category.products.includes([:sub_categories]).where(brand_id: @brand.id)
                            .order('LOWER(name)').page(params[:page])

    add_breadcrumb I18n.t('headings.brands'), brands_path
    add_breadcrumb @brand.name, brand_path(id: @brand.friendly_id)
    add_breadcrumb sub_category.name

    @page_title = @brand.name

    render :show
  end

  def new
    @active_menu = :brands
    @page_title = I18n.t('new_brand.heading')

    add_breadcrumb I18n.t('headings.brands'), brands_path
    add_breadcrumb I18n.t('new_brand.heading')

    @brand = Brand.new
  end

  def create
    @active_menu = :brands

    @brand = Brand.new(brand_params)

    if @brand.save
      redirect_to brand_path(@brand)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def brand_params
    params.require(:brand).permit(:name, :discontinued)
  end
end
