# frozen_string_literal: true

class BrandFilterService
  include FilterConstants
  include FilterableService

  # Result struct for returning filter results
  Result = Struct.new(:brands, keyword_init: true)

  def initialize(params, category = nil, sub_category = nil)
    @params = params.to_h.symbolize_keys.slice(
      :letter, :status, :country, :diy_kit, :attr, :query, :sort
    )
    @category = category
    @sub_category = sub_category
    @brands = Brand.all
  end

  def filter
    brands = @brands

    if @sub_category
      brands = brands.joins(:sub_categories).where(sub_categories: { id: @sub_category.id })
    elsif @category
      brands = brands.joins(:sub_categories).where(sub_categories: { category_id: @category.id })
    end

    brands = apply_ordering(brands, @params)
    brands = apply_letter_filter(brands, @params, 'brands.name')
    brands = apply_status_filter(brands, @params)
    brands = apply_country_filter(brands, @params)
    brands = apply_diy_kit_filter(brands, @params)
    brands = apply_custom_attributes_filter(brands, @params)
    brands = apply_search_filter(brands, @params)
    brands = brands.select('brands.*, LOWER(brands.name) AS lower_name').distinct

    Result.new(brands:)
  end

  private

  def apply_country_filter(scope, params)
    return scope if params[:country].blank?

    scope.where(country_code: params[:country].upcase)
  end

  def apply_diy_kit_filter(scope, params)
    return scope if params[:diy_kit].blank?

    diy_kit = params[:diy_kit] == '1'
    scope = scope.left_joins(products: [:product_variants])
    scope.where(products: { product_variants: { diy_kit: } })
         .or(scope.where(products: { diy_kit: }))
         .distinct
  end

  def apply_custom_attributes_filter(scope, params)
    return scope if params[:attr].blank?

    relevant_ids = params[:attr].keys.map(&:to_i)
    CustomAttribute.where(id: relevant_ids).find_each do |custom_attribute|
      id_s = custom_attribute.id.to_s
      next if params[:attr][id_s].blank?

      scope = scope.joins(:products)
                   .where('custom_attributes ->> ? IN (?)', id_s, params[:attr][id_s])
                   .distinct
    end
    scope
  end

  def apply_search_filter(scope, params)
    return scope if params[:query].blank?

    scope.search_by_name(params[:query].strip).with_pg_search_rank
  end

  def apply_status_filter(scope, params, discontinued_column = 'discontinued')
    return scope unless params[:status].present? && STATUSES.include?(params[:status])

    scope.where(discontinued_column => params[:status] == 'discontinued')
  end

  def apply_ordering(scope, params)
    order = case params[:sort]
            when 'name_desc' then 'lower_name DESC'
            when 'products_asc' then 'brands.products_count ASC NULLS FIRST, lower_name'
            when 'products_desc' then 'brands.products_count DESC NULLS LAST, lower_name'
            when 'country_asc' then 'brands.country_code ASC, lower_name'
            when 'country_desc' then 'brands.country_code DESC, lower_name'
            when 'added_asc' then 'brands.created_at ASC, lower_name'
            when 'added_desc' then 'brands.created_at DESC, lower_name'
            when 'updated_asc' then 'brands.updated_at ASC, lower_name'
            when 'updated_desc' then 'brands.updated_at DESC, lower_name'
            else 'lower_name ASC'
            end

    scope.order(order)
  end
end
