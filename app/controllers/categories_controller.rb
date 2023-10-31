class CategoriesController < ApplicationController
  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("headings.categories").html_safe, :categories_path

  def index
    @active_menu = :categories

    @categories = Category.all.sort_by{|c| c[:name].downcase}

    if params[:id].present?
      @sub_categories = SubCategory.select{ |sub_category| sub_category.category_id == params[:id].to_i }.sort_by{|c| c[:name].downcase}
    else
      @sub_categories = SubCategory.all.sort_by{|c| c[:name].downcase}
    end
  end

  def show
    @active_menu = :categories

    @category = Category.friendly.find(params[:id])
    @categories = Category.all.sort_by{|c| c[:name].downcase}
    @sub_categories = @category.sub_categories.sort_by{|c| c[:name].downcase}

    add_breadcrumb @category.name, category_path(@category)
  end
end
