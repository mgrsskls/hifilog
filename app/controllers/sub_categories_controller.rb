class SubCategoriesController < ApplicationController
  add_breadcrumb I18n.t('headings.categories').html_safe, :categories_path

  def show
    @active_menu = :categories

    @sub_category = SubCategory.friendly.find(params[:id])
    @category = Category.friendly.find(params[:category_id])

    add_breadcrumb @category.name, category_path(@category)

    if params[:sort].present?
      order = 'LOWER(name) ASC' if params[:sort] == 'name_asc'
      order = 'LOWER(name) DESC' if params[:sort] == 'name_desc'
      if params[:sort] == 'release_date_asc'
        order = 'release_year ASC NULLS LAST, release_month ASC NULLS LAST, release_day ASC NULLS LAST, LOWER(name)'
      end
      if params[:sort] == 'release_date_desc'
        order = 'release_year DESC NULLS LAST, release_month DESC NULLS LAST, release_day DESC NULLS LAST, LOWER(name)'
      end
      order = 'created_at ASC, LOWER(name)' if params[:sort] == 'added_asc'
      order = 'created_at DESC, LOWER(name)' if params[:sort] == 'added_desc'
      order = 'updated_at ASC, LOWER(name)' if params[:sort] == 'updated_asc'
      order = 'updated_at DESC, LOWER(name)' if params[:sort] == 'updated_desc'
    else
      order = 'LOWER(name) ASC'
    end

    if params[:letter].present?
      add_breadcrumb @sub_category.name, category_sub_category_path(
        id: @sub_category.id,
        category_id: @sub_category.category_id
      )
      add_breadcrumb params[:letter].upcase
      @products = @sub_category.products.includes([:brand])
                               .where('left(lower(name),1) = :prefix', prefix: params[:letter].downcase)
                               .order(order).page(params[:page])
    else
      add_breadcrumb @sub_category.name
      @products = @sub_category.products.includes([:brand]).order(order).page(params[:page])
    end

    @page_title = @sub_category.name
  end

  private

  def update_for_joined_tables(order)
    order
      .sub('LOWER(name)', 'LOWER(products.name)')
      .sub('release_year', 'products.release_year')
      .sub('release_month', 'products.release_month')
      .sub('release_day', 'products.release_day')
      .sub('created_at', 'products.created_at')
      .sub('updated_at', 'products.updated_at')
  end
end
