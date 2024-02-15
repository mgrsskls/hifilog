class SearchController < ApplicationController
  add_breadcrumb I18n.t('search')

  def results
    min_chars = 2

    @page_title = I18n.t('search')
    @no_index = true
    @query = params[:query].strip
    query_split_up = @query.split

    if @query.length < min_chars
      flash.now[:alert] = I18n.t('search_results.alert.minimum_chars', min: min_chars)
    else
      @products = Product.search_by_display_name(query_split_up).limit(20).with_pg_search_rank
      @brands = Brand.search_by_name(query_split_up).limit(20).with_pg_search_rank

      @highest_products_rank = @products.map(&:pg_search_rank).max
      @highest_brands_rank = @brands.map(&:pg_search_rank).max
    end
  end
end
