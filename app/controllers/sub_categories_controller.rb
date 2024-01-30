class SubCategoriesController < ApplicationController
  add_breadcrumb I18n.t('headings.categories').html_safe, :categories_path

  def show
    @active_menu = :categories

    @sub_category = SubCategory.friendly.find(params[:id])
    @category = Category.friendly.find(params[:category_id])

    add_breadcrumb @category.name, category_path(@category)

    if params[:letter].present?
      add_breadcrumb @sub_category.name, category_sub_category_path(@sub_category)
      add_breadcrumb params[:letter].upcase
      @products = @sub_category.products.includes([:brand])
                               .where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
                               .order('LOWER(name)').page(params[:page])
    else
      add_breadcrumb @sub_category.name
      @products = @sub_category.products.includes([:brand]).order('LOWER(name)').page(params[:page])
    end

    @page_title = @sub_category.name
  end
end
