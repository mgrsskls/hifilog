class ProductsController < ApplicationController
  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("headings.products"), :products_path

  def index
    @active_menu = :products

    if params[:letter]
      @products = Product.where("name LIKE :prefix", prefix: "#{params[:letter]}%").sort_by{|p| p[:name].downcase}
    else
      @products = Product.all.sort_by{|p| p[:name].downcase}
    end
  end

  def show
    @active_menu = :products

    @product = Product.find(params[:id])

    add_breadcrumb @product.manufacturer.name, manufacturer_path(@product.manufacturer)
    add_breadcrumb @product.name
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to @product
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def product_params
    params.require(:product).permit(:name, :manufacturer_id)
  end
end
