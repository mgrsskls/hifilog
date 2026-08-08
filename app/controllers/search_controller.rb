# frozen_string_literal: true

class SearchController < ApplicationController
  include RelevanceOrdering

  MIN_CHARS = 2

  # Exact/prefix matches only count against the field that actually names the row: a
  # brand's own name/full_name for a Brand row, the product's own name/variant/model_no
  # for a Product or ProductVariant row. Without this split, any product belonging to a
  # brand whose name exactly matches the query (e.g. "zmf") would tie the brand's own
  # row for the top tier, and often outrank it on the hand-picked sort.
  RELEVANCE_EXACT_COLUMNS = [
    "CASE WHEN search_results.item_type = 'Brand' THEN search_results.brand_name END",
    "CASE WHEN search_results.item_type = 'Brand' THEN search_results.brand_full_name END",
    "CASE WHEN search_results.item_type != 'Brand' THEN search_results.product_name END",
    "CASE WHEN search_results.item_type != 'Brand' THEN search_results.product_variant_name END",
    "CASE WHEN search_results.item_type != 'Brand' THEN search_results.model_no END"
  ].freeze

  # The broader "does this row mention the query anywhere" check, and the closeness
  # score that breaks ties within a tier, still consider every field -- a product from
  # a matched brand is still a relevant result, just not an exact/prefix one.
  RELEVANCE_CONTAINS_COLUMNS = %w[
    search_results.product_name
    search_results.product_variant_name
    search_results.brand_name
    search_results.brand_full_name
    search_results.model_no
  ].freeze

  def results
    @query = params[:query].presence&.strip

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
              results: query_results
            }
          )
        }
      end
    else
      page_title(I18n.t('search'))
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
    results = apply_ordering(SearchResult.search_by_name(@query))

    return results.page(params[:page]) unless params[:filter].present? && %w[products brands].include?(params[:filter])

    item_type = case params[:filter]
                when 'products' then %w[Product ProductVariant]
                when 'brands' then ['Brand']
                end

    results.where(item_type:).page(params[:page])
  end

  # Ordering goes last: `reorder` has to overwrite the `rank DESC` that
  # search_by_name appended.
  def apply_ordering(scope)
    tier = relevance_tier_sql(@query, exact: RELEVANCE_EXACT_COLUMNS, contains: RELEVANCE_CONTAINS_COLUMNS)
    return scope unless tier

    scope.reorder(Arel.sql("#{tier}, search_results.id"))
  end
end
