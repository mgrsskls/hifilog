# frozen_string_literal: true

class BrandFilterService
  include FilterConstants
  include FilterableService
  include RelevanceOrdering

  SEARCH_COLUMNS = ['brands.name', 'brands.full_name'].freeze

  Result = Struct.new(:brands)

  def initialize(brands: [], filters: {}, product_filters: {}, category: nil, sub_category: nil)
    @filters = filters
    @category = category
    @sub_category = sub_category
    @brands = brands.any? ? brands : Brand.all
    @product_filters = product_filters
  end

  def filter
    brands = @brands

    if @sub_category
      brands = brands.where(<<~SQL.squish, sub_category_id: @sub_category.id)
        EXISTS (
          SELECT 1 FROM brands_sub_categories
          WHERE brands_sub_categories.brand_id = brands.id
            AND brands_sub_categories.sub_category_id = :sub_category_id
        )
      SQL
    elsif @category
      brands = brands.where(<<~SQL.squish, category_id: @category.id)
        EXISTS (
          SELECT 1 FROM brands_sub_categories
          INNER JOIN sub_categories ON sub_categories.id = brands_sub_categories.sub_category_id
          WHERE brands_sub_categories.brand_id = brands.id
            AND sub_categories.category_id = :category_id
        )
      SQL
    end

    if (status = @filters[:status].presence)
      brands = apply_status_filter(brands, status)
    end
    if (country = @filters[:country].presence)
      brands = apply_country_filter(brands, country)
    end

    query = @filters[:query].presence
    brands = apply_search_filter(brands, query) if query

    if @product_filters.present?
      filtered_products_relation = ProductFilterService.new(
        filters: @product_filters,
        brands:,
        category: @category,
        sub_category: @sub_category
      ).filter.products

      # ORDER BY is irrelevant inside the IN (...) subquery and only makes Postgres
      # sort product_items for nothing.
      brands = brands.where(id: filtered_products_relation.except(:order).select(:brand_id))
    end

    # Ordering goes last: `reorder` has to overwrite the `rank DESC` that
    # search_by_name appended.
    brands = apply_ordering(brands, @filters[:sort], query:)

    Result.new(brands:)
  end

  private

  def apply_country_filter(scope, value)
    scope.where(country_code: value.strip.upcase)
  end

  def apply_search_filter(scope, value)
    scope.search_by_name(value.strip)
  end

  def apply_status_filter(scope, value)
    discontinued = value == 'discontinued'

    scope.where(discontinued:)
  end

  # ORDER BY, in order of precedence:
  #   1. relevance (only with a query; beats the hand-picked sort)
  #   2. hand-picked sort
  #   3. brands.id (LOWER(name) is not unique enough for stable paging)
  def apply_ordering(scope, value, query: nil)
    order = ordering_for(value&.downcase)

    if (tier = relevance_tier_sql(query, exact: SEARCH_COLUMNS,
                                         contains: SEARCH_COLUMNS))
      order = [tier, order].join(', ')
    end

    scope.reorder(Arel.sql("#{order}, brands.id"))
  end

  def ordering_for(sort)
    case sort
    when 'name_desc'
      'LOWER(brands.name) DESC'
    when 'added_asc'
      'brands.created_at ASC, LOWER(brands.name)'
    when 'added_desc'
      'brands.created_at DESC, LOWER(brands.name)'
    when 'updated_asc'
      'brands.updated_at ASC, LOWER(brands.name)'
    when 'updated_desc'
      'brands.updated_at DESC, LOWER(brands.name)'
    else
      'LOWER(brands.name) ASC'
    end
  end
end
