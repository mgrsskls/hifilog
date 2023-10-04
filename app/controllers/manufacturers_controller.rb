class ManufacturersController < ApplicationController
  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("headings.manufacturers").html_safe, :manufacturers_path

  def index
    @active_menu = :manufacturers

    if params[:letter]
      add_breadcrumb params[:letter].upcase
      all_manufacturers = Manufacturer.where("name LIKE :prefix", prefix: "#{params[:letter]}%")
    else
      all_manufacturers = Manufacturer.all
    end

    @manufacturers = all_manufacturers.order("LOWER(name)").page(params[:page])
    @total_size = all_manufacturers.size
  end

  def show
    @active_menu = :manufacturers

    @manufacturer = Manufacturer.friendly.find(params[:id])
    @products = @manufacturer.products.order("LOWER(name)").page(params[:page])

    add_breadcrumb @manufacturer.name
  end

  def category
    sub_category = SubCategory.friendly.find(params[:category])
    @manufacturer = Manufacturer.friendly.find(params[:manufacturer_id])
    @products = sub_category.products.where(manufacturer_id: @manufacturer.id).order("LOWER(name)").page(params[:page])
    add_breadcrumb @manufacturer.name, manufacturer_path(id: @manufacturer.friendly_id)
    add_breadcrumb sub_category.name

    render :show
  end

  def new
    @manufacturer = Manufacturer.new
  end

  def create
    @manufacturer = Manufacturer.new(manufacturer_params)

    if @manufacturer.save
      redirect_to @manufacturer
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def manufacturer_params
    params.require(:manufacturer).permit(:name)
  end
end
