class BrandsController < ApplicationController
  before_action :authenticate_user!, only: [:create]

  add_breadcrumb I18n.t('headings.brands').html_safe, :brands_path

  def index
    @active_menu = :brands
    @page_title = I18n.t('headings.brands')

    if params[:letter]
      add_breadcrumb params[:letter].upcase
      @brands = Brand.where('name ILIKE :prefix', prefix: "#{params[:letter]}%")
                     .order('LOWER(name)')
                     .page(params[:page])
    else
      @brands = Brand.all.order('LOWER(name)').page(params[:page])
    end

    @total_size = @brands.size
  end

  def show
    @active_menu = :brands

    @brand = Brand.friendly.find(params[:id])
    @products = @brand.products.includes([:sub_categories]).order('LOWER(name)').page(params[:page])

    add_breadcrumb @brand.name
    @page_title = @brand.name
  end

  def category
    @active_menu = :brands

    sub_category = SubCategory.friendly.find(params[:category])
    @brand = Brand.friendly.find(params[:brand_id])
    @products = sub_category.products.includes([:sub_categories]).where(brand_id: @brand.id)
                            .order('LOWER(name)').page(params[:page])
    add_breadcrumb @brand.name, brand_path(id: @brand.friendly_id)
    add_breadcrumb sub_category.name

    @page_title = @brand.name

    render :show
  end

  def new
    @active_menu = :brands
    @page_title = I18n.t('new_brand.heading')

    add_breadcrumb t('add')

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
