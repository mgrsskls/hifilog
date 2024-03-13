class SearchController < ApplicationController
  add_breadcrumb I18n.t('search')

  MIN_CHARS = 2

  def results
    @page_title = I18n.t('search')
    @no_index = true
    @query = params[:query].present? ? params[:query].strip : nil

    if @query.nil? || @query.length < MIN_CHARS
      flash.now[:alert] = I18n.t('search_results.alert.minimum_chars', min: MIN_CHARS)
    else
      query_split_up = @query.split
      @products = get_products(query_split_up, 20)
      @brands = get_brands(query_split_up, 20)
    end
  end

  private

  def get_products(query, limit)
    Product.search_by_name_and_description(query).limit(limit).includes([:brand, :sub_categories])
  end

  def get_brands(query, limit)
    Brand.search_by_name_and_description(query).limit(limit)
  end
end
