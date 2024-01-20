class CategoriesController < ApplicationController
  add_breadcrumb 'Hifi Gear', :root_path
  add_breadcrumb I18n.t('headings.categories').html_safe, :categories_path

  def index
    @active_menu = :categories

    @categories = Category.all.sort_by { |c| c[:name].downcase }

    sub_categories = if params[:id].present?
                       SubCategory.select do |sub_category|
                         sub_category.category_id == params[:id].to_i
                       end
                     else
                       SubCategory.all
                     end
    @sub_categories = sub_categories.sort_by { |c| c[:name].downcase }
  end

  def show
    @active_menu = :categories

    @category = Category.friendly.find(params[:id])
    @categories = Category.all.sort_by { |c| c[:name].downcase }
    @sub_categories = @category.sub_categories.sort_by { |c| c[:name].downcase }

    add_breadcrumb @category.name, category_path(@category)
  end
end
