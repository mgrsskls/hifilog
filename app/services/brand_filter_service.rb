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
      brands = brands.joins(:sub_categories).where(sub_categories: { id: @sub_category.id })
    elsif @category
      brands = brands.joins(:sub_categories).where(sub_categories: { category_id: @category.id })
    end

    brands = apply_ordering(brands, @filters[:sort])
    brands = apply_status_filter(brands, @filters[:status]) if @filters[:status].present?
    brands = apply_country_filter(brands, @filters[:country]) if @filters[:country].present?
    brands = apply_search_filter(brands, @filters[:query]) if @filters[:query].present?
    brands = brands.select('brands.*, LOWER(brands.name)').distinct

    if @product_filters.present? && @product_filters[:custom].present? && @product_filters[:custom][:products].present?
      brand_ids_from_product_filter = ProductFilterService.new(
        filters: {
          custom: @product_filters[:custom][:products]
        },
        brands:,
      ).filter.products.map(&:brand_id).uniq
      brands = brands.where(id: brand_ids_from_product_filter)
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
    order = case value&.downcase
            when 'name_desc' then 'LOWER(brands.name) DESC'
            when 'products_asc' then 'brands.products_count ASC NULLS FIRST, LOWER(brands.name)'
            when 'products_desc' then 'brands.products_count DESC NULLS LAST, LOWER(brands.name)'
            when 'added_asc' then 'brands.created_at ASC, LOWER(brands.name)'
            when 'added_desc' then 'brands.created_at DESC, LOWER(brands.name)'
            when 'updated_asc' then 'brands.updated_at ASC, LOWER(brands.name)'
            when 'updated_desc' then 'brands.updated_at DESC, LOWER(brands.name)'
            else 'LOWER(brands.name) ASC'
            end

    scope.order(order)
  end
end
