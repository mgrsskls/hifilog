class CategoriesController < ApplicationController
  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("headings.categories"), :categories_path

  def index
    @active_menu = :categories

    @categories = Category.all.sort_by{|c| c[:name].downcase}
  end

  def show
    @active_menu = :categories

    @category = Category.find(params[:id])

    if @category.sub_categories.size > 0
      @sub_categories = @category.sub_categories
    else
      @products = @category.products
      render "sub_category"
    end

    # if @category.sub_categories.size > 0
    #   @sub_categories = @category.products.group_by(&:sub_category).sort_by{|c| c[0].name.downcase}
    # else
    #   @sub_categories = [[nil, @category.products.sort_by{|p| p.name.downcase}]]
    # end

    add_breadcrumb @category.name, category_path(@category)
  end

  def sub_category
    @active_menu = :categories

    category = Category.find(params[:category_id])

    @category = SubCategory.find(params[:sub_category_id])
    @products = category.products.select{ |p| p.sub_category_id == params[:sub_category_id].to_i }

    add_breadcrumb category.name, category_path(category)
    add_breadcrumb @category.name
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to @category
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def category_params
    params.require(:category).permit(:name)
  end
end
