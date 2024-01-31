class CategoriesController < ApplicationController
  add_breadcrumb I18n.t('headings.categories').html_safe, :categories_path

  def index
    @active_menu = :categories
    @page_title = I18n.t('headings.categories')

    @categories = Category.ordered

    sub_categories = if params[:id].present?
                       SubCategory.where(category_id: params[:id].to_i).includes([:category]).order('LOWER(name)')
                     else
                       SubCategory.all.includes([:category]).order('LOWER(name)')
                     end
    @sub_categories = sub_categories
  end

  def show
    @active_menu = :categories

    @category = Category.friendly.find(params[:id])
    @categories = Category.ordered
    @sub_categories = @category.sub_categories.order('LOWER(name)')

    add_breadcrumb @category.name, category_path(@category)
    @page_title = @category.name
  end
end
