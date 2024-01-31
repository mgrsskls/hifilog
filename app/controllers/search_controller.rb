class SearchController < ApplicationController
  add_breadcrumb I18n.t('search')

  def results
    min_chars = 2

    @page_title = I18n.t('search')
    @query = params[:query].strip

    if params[:query].length < min_chars
      flash.now[:alert] = I18n.t('search_results.alert.minimum_chars', min: min_chars)
    else
      query = "%#{params[:query]}%"

      @products = Product.where('name ILIKE ?', query).includes([:brand, :sub_categories])
                         .sort_by { |a| -(query.length - a.name.length) }
      @brands = Brand.where('name ILIKE ?', query).includes([:products])
                     .sort_by { |a| -(query.length - a.name.length) }
    end
  end
end
