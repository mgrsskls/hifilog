class SubCategoriesController < ApplicationController
  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("headings.categories").html_safe, :categories_path

  def show
    @active_menu = :categories

    @sub_category = SubCategory.friendly.find(params[:id])
    @category = Category.find(@sub_category.category.id)
    @filter_all_path = category_sub_category_path(id: params[:id], category_id: params[:category_id])
    @filter_paths = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'].map { |letter| { path: letter_category_sub_categories_path(id: params[:id], category_id: params[:category_id], letter: letter), letter: letter } }

    add_breadcrumb @category.name, category_path(@category)

    if params[:letter]
      add_breadcrumb @sub_category.name, category_sub_category_path(@sub_category)
      add_breadcrumb params[:letter].upcase
      @products = @sub_category.products.where("name LIKE :prefix", prefix: "#{params[:letter]}%").order("LOWER(name)").page(params[:page])
    else
      add_breadcrumb @sub_category.name
      @products = @sub_category.products.order("LOWER(name)").page(params[:page])
    end
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
