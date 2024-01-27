class SubCategoriesController < ApplicationController
  include ApplicationHelper

  add_breadcrumb I18n.t('headings.categories').html_safe, :categories_path

  def show
    @active_menu = :categories

    @sub_category = SubCategory.friendly.find(params[:id])
    @category = Category.friendly.find(params[:category_id])
    @filter_all_path = category_sub_category_path(id: params[:id], category_id: params[:category_id])
    @filter_paths = helpers.abc.map do |letter|
      {
        path: category_sub_category_path(id: params[:id], category_id: params[:category_id], letter:),
        letter:
      }
    end

    add_breadcrumb @category.name, category_path(@category)

    if abc.include?(params[:letter])
      add_breadcrumb @sub_category.name, category_sub_category_path(@sub_category)
      add_breadcrumb params[:letter].upcase
      all_products = @sub_category.products.includes([:brand])
                               .where('name ILIKE :prefix', prefix: "#{params[:letter]}%")
    else
      add_breadcrumb @sub_category.name
      all_products = @sub_category.products.includes([:brand])
    end

    ordered = all_products.order('LOWER(name)')
    paginated = ordered.page(params[:page])

    @products = params[:page].to_i > paginated.total_pages ? ordered.page(1) : paginated

    @page_title = @sub_category.name
  end
end
