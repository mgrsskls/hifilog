class SearchController < ApplicationController
  add_breadcrumb I18n.t('search')

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
        add_breadcrumb "“#{@query}”"
        @results = query_results
      end
    end
  end

  private

  def query_results
    query_arr = [@query]
    query_split_up = @query.split
    query_arr += query_split_up + [query_split_up.join] if query_split_up.size > 1
    results = PgSearch.multisearch(query_arr).with_pg_search_highlight.page(params[:page])

    if params[:filter].present? && %w[products brands].include?(params[:filter])
      searchable_type = case params[:filter]
                        when 'products' then %w[Product ProductVariant]
                        when 'brands' then ['Brand']
                        end

      results = results.where(searchable_type:)
    end

    results
  end
end
