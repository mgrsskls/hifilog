class ManufacturersController < ApplicationController
  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("headings.manufacturers"), :manufacturers_path

  def index
    @active_menu = :manufacturers

    if params[:letter]
      @manufacturers = Manufacturer.where("name LIKE :prefix", prefix: "#{params[:letter]}%").sort_by{|m| m[:name].downcase}
    else
      @manufacturers = Manufacturer.all.sort_by{|m| m[:name].downcase}
    end
  end

  def show
    @active_menu = :manufacturers

    @manufacturer = Manufacturer.find_by(id: params[:id])
    @products = @manufacturer.products.group_by{|p| p.category_id}.map{ |category| {
      title: Category.find(category[0].kind_of?(Array) ? category[0][0] : category[0]).name,
      sub_categories: category[1].group_by{|e| e.sub_category_id}.map{ |sub_category| {
        title: sub_category[0] ? SubCategory.find(sub_category[0]).name : nil,
        products: sub_category[1].sort_by{|c| c[:name].downcase},
      } }
    } }.sort_by{|m| m[:title].downcase}

    add_breadcrumb @manufacturer.name
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
