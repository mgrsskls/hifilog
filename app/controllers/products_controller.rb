class ProductsController < ApplicationController
  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("headings.products"), :products_path

  def index
    @active_menu = :products

    if params[:letter]
      add_breadcrumb params[:letter].upcase
      all_products = Product.where("name LIKE :prefix", prefix: "#{params[:letter]}%")
    else
      all_products = Product.all
    end

    @products = all_products.order("LOWER(name)").page(params[:page])
    @total_size = all_products.size
  end

  def show
    @active_menu = :products

    @manufacturer = Manufacturer.friendly.find(params[:manufacturer_id])
    @product = @manufacturer.products.friendly.find(params[:id])
    @user_has_product = user_signed_in? ? current_user.products.include?(@product) : false;
    @rooms = user_signed_in? ? current_user.rooms.select { |room| room.products.include?(@product) } : []

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
