class SubCategoriesController < ApplicationController
  add_breadcrumb APP_NAME, :root_path
  add_breadcrumb I18n.t('headings.categories').html_safe, :categories_path

  def show
    @active_menu = :categories

    @sub_category = SubCategory.friendly.find(params[:id])
    @category = Category.find(@sub_category.category.id)
    @filter_all_path = category_sub_category_path(id: params[:id], category_id: params[:category_id])
    @filter_paths = helpers.abc.map do |letter|
      { path: letter_category_sub_categories_path(id: params[:id], category_id: params[:category_id], letter:),
        letter: }
    end

    add_breadcrumb @category.name, category_path(@category)

    if params[:letter]
      add_breadcrumb @sub_category.name, category_sub_category_path(@sub_category)
      add_breadcrumb params[:letter].upcase
      @products = @sub_category.products.includes([:brand]).where('name ILIKE :prefix',
                                               prefix: "#{params[:letter]}%").order('LOWER(name)').page(params[:page])
    else
      add_breadcrumb @sub_category.name
      @products = @sub_category.products.includes([:brand]).order('LOWER(name)').page(params[:page])
    end
  end
end
