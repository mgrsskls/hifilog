class SearchController < ApplicationController
  MIN_CHARS = 2

  def results
    @query = params[:query].present? ? params[:query].strip : nil

    if request.xhr?
      if @query.nil? || @query.length < MIN_CHARS
        render json: {
          query: @query,
          html: nil
        }
      else
        render json: {
          query: @query,
          html: render_to_string(
            partial: 'xhr_list', locals: {
              query: @query,
              results: query_results,
            }
          )
        }
      end
    else
      @page_title = I18n.t('search')
      @no_index = true

      if @query.nil? || @query.length < MIN_CHARS
        flash.now[:alert] = I18n.t('search_results.alert.minimum_chars', min: MIN_CHARS)
      else
        @results = query_results
      end
    end
  end

  private

  def query_results
    results = SearchResult.search(@query).page(params[:page])

    return results unless params[:filter].present? && %w[products brands].include?(params[:filter])

    item_type = case params[:filter]
                when 'products' then %w[Product ProductVariant]
                when 'brands' then ['Brand']
                end

    results.where(item_type:)
  end
end
