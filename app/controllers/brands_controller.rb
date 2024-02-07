class BrandsController < ApplicationController
  STATUSES = %w[discontinued continued].freeze

  before_action :set_paper_trail_whodunnit, only: [:create, :update]
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :changelog]
  before_action :set_breadcrumb, only: [:show, :new, :edit, :changelog]
  before_action :set_active_menu

  def index
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
    @brand = Brand.friendly.find(params[:id])

    if params[:category]
      sub_category = SubCategory.friendly.find(params[:category])
      @products = sub_category.products.includes([:sub_categories]).where(brand_id: @brand.id)
                              .order('LOWER(name)').page(params[:page])
      add_breadcrumb @brand.name, proc { :brand }
      add_breadcrumb sub_category.name
    else
      @products = @brand.products.includes([:sub_categories]).order('LOWER(name)').page(params[:page])
      add_breadcrumb @brand.name
    end

    @page_title = @brand.name
  end

  def new
    @page_title = I18n.t('new_brand.heading')

    add_breadcrumb I18n.t('new_brand.heading')

    @brand = Brand.new
  end

  def create
    @brand = Brand.new(brand_params)

    if @brand.save
      redirect_to brand_path(@brand)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @brand = Brand.friendly.find(params[:id])
    @page_title = I18n.t('edit_record', name: @brand.name)

    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb I18n.t('edit')
  end

  def update
    @brand = Brand.friendly.find(params[:id])

    if @brand.update(brand_params)
      redirect_to brand_path(@brand)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def changelog
    @brand = Brand.friendly.find(params[:brand_id])

    add_breadcrumb @brand.name, brand_path(@brand)
    add_breadcrumb I18n.t('headings.changelog')
  end

  private

  def set_active_menu
    @active_menu = :brands
  end

  def set_breadcrumb
    add_breadcrumb I18n.t('headings.brands'), brands_path
  end

  def brand_params
    params.require(:brand).permit(:name, :discontinued, :full_name, :website, :country_code)
  end
end
