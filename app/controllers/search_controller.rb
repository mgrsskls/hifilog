class SearchController < ApplicationController
  add_breadcrumb I18n.t('search')

  def results
    min_chars = 2

    @page_title = I18n.t('search')
    @no_index = true
    @query = params[:query].strip

    if @query.length < min_chars
      flash.now[:alert] = I18n.t('search_results.alert.minimum_chars', min: min_chars)
    else
      query = "%#{@query}%"

      @products = Product.where('name ILIKE ?', query)
                         .limit(20)
                         .order('CHAR_LENGTH(name)')
                         .includes([:brand, :sub_categories])
                         .group_by { |product| product.name.length }
                         .flat_map { |group| group[1].sort_by { |a| a.name.downcase.index(@query) } }

      @brands = Brand.where('name ILIKE ?', query)
                     .limit(20)
                     .order('CHAR_LENGTH(name)')
                     .group_by { |brand| brand.name.length }
                     .flat_map { |group| group[1].sort_by { |a| a.name.downcase.index(@query) } }

    end
  end
end
