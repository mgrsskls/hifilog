# frozen_string_literal: true

class BrandFilterService
  include FilterConstants
  include FilterableService

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

    brands = apply_ordering(brands, @filters[:sort])
    if (status = @filters[:status].presence)
      brands = apply_status_filter(brands, status)
    end
    if (country = @filters[:country].presence)
      brands = apply_country_filter(brands, country)
    end
    if (query = @filters[:query].presence)
      brands = apply_search_filter(brands, query)
    end

    if @product_filters.present?
      filtered_products_relation = ProductFilterService.new(
        filters: @product_filters,
        brands:
      ).filter.products

      brands = brands.where(id: filtered_products_relation.select(:brand_id))
    end

    Result.new(brands:)
  end

  private

  def apply_country_filter(scope, value)
    scope.where(country_code: value.strip.upcase)
  end

  def apply_search_filter(scope, value)
    scope.search_by_name(value.strip).with_pg_search_rank
  end

  def apply_status_filter(scope, value)
    discontinued = value == 'discontinued'

    scope.where(discontinued:)
  end

  def apply_ordering(scope, value)
    sort = value&.downcase

    case sort
    when 'products_asc', 'products_desc'
      if matching_products_count_ordering?
        # Match brands#index counts: product_items (incl. variants), with category/product filters.
        # brands.products_count is total products only and ignores those filters.
        order_by_matching_products_count(scope, sort)
      elsif sort == 'products_asc'
        scope.order('brands.products_count ASC NULLS FIRST, LOWER(brands.name)')
      else
        scope.order('brands.products_count DESC NULLS LAST, LOWER(brands.name)')
      end
    when 'name_desc'
      scope.order('LOWER(brands.name) DESC')
    when 'completeness_asc'
      scope.order('brands.completeness ASC, brands.created_at DESC, LOWER(brands.name)')
    when 'completeness_desc'
      scope.order('brands.completeness DESC, brands.created_at DESC, LOWER(brands.name)')
    when 'added_asc'
      scope.order('brands.created_at ASC, LOWER(brands.name)')
    when 'added_desc'
      scope.order('brands.created_at DESC, LOWER(brands.name)')
    when 'updated_asc'
      scope.order('brands.updated_at ASC, LOWER(brands.name)')
    when 'updated_desc'
      scope.order('brands.updated_at DESC, LOWER(brands.name)')
    else
      scope.order('LOWER(brands.name) ASC')
    end
  end

  def matching_products_count_ordering?
    @category.present? || @sub_category.present? || @product_filters.present?
  end

  def order_by_matching_products_count(scope, sort)
    matching_products = ProductFilterService.new(
      filters: @product_filters,
      category: @category,
      sub_category: @sub_category
    ).filter.products.except(:order)

    counts_sql = matching_products
                 .group(:brand_id)
                 .select('product_items.brand_id, COUNT(*) AS matching_products_count')
                 .to_sql

    direction = sort == 'products_asc' ? 'ASC' : 'DESC'

    scope
      .joins(<<~SQL.squish)
        LEFT OUTER JOIN (#{counts_sql}) AS matching_product_counts
          ON matching_product_counts.brand_id = brands.id
      SQL
      .order(
        Arel.sql(
          "COALESCE(matching_product_counts.matching_products_count, 0) #{direction}, LOWER(brands.name)"
        )
      )
  end
end
