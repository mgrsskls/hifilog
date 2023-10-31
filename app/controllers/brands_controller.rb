class BrandsController < ApplicationController
  before_action :authenticate_user!, only: [:create]

  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("headings.brands").html_safe, :brands_path

  def index
    @active_menu = :brands

    if params[:letter]
      add_breadcrumb params[:letter].upcase
      all_brands = Brand.where("name LIKE :prefix", prefix: "#{params[:letter]}%")
    else
      all_brands = Brand.all
    end

    @brands = all_brands.order("LOWER(name)").page(params[:page])
    @total_size = all_brands.size
  end

  def show
    @active_menu = :brands

    @brand = Brand.friendly.find(params[:id])
    @products = @brand.products.order("LOWER(name)").page(params[:page])

    add_breadcrumb @brand.name
  end

  def category
    sub_category = SubCategory.friendly.find(params[:category])
    @brand = Brand.friendly.find(params[:brand_id])
    @products = sub_category.products.where(brand_id: @brand.id).order("LOWER(name)").page(params[:page])
    add_breadcrumb @brand.name, brand_path(id: @brand.friendly_id)
    add_breadcrumb sub_category.name

    render :show
  end

  def new
    add_breadcrumb t("add")

    @brand = Brand.new
  end

  def create
    @brand = Brand.new(brand_params)

    if @brand.save
      redirect_to @brand
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def brand_params
    params.require(:brand).permit(:name)
  end
end
