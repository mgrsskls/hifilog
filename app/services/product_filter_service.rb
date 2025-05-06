# frozen_string_literal: true

# Service for filtering products based on params
class ProductFilterService
  include FilterConstants
  include FilterableService

  # Result struct for returning filter results
  Result = Struct.new(:products, keyword_init: true)

  def initialize(params, brand, category = nil, sub_category = nil)
    @params = params.to_h.symbolize_keys
    @brand = brand
    @category = category
    @sub_category = sub_category
    @products = brand.products
  end

  def filter
    products = @products

    if @sub_category
      products = products.left_outer_joins(:sub_categories).where(sub_categories: { id: @sub_category.id })
    elsif @category
      products = products.left_outer_joins(:sub_categories).where(sub_categories: { category_id: @category.id })
    end

    products = apply_ordering(products, @params)
    products = apply_letter_filter(products, @params, 'products.name')
    products = apply_status_filter(products, @params)
    products = apply_diy_kit_filter(products, @params)
    products = apply_custom_attributes_filter(products, @params)
    products = apply_search_filter(products, @params)
    products = products.select('products.*, LOWER(products.name) AS lower_name').distinct
    Result.new(products:)
  end

  private

  def apply_status_filter(scope, params)
    return scope unless params[:status].present? && STATUSES.include?(params[:status])

    discontinued = params[:status] == 'discontinued'

    scope.left_outer_joins(:product_variants)
         .where(product_variants: { discontinued: })
         .or(scope.where(discontinued:))
  end

  def apply_diy_kit_filter(scope, params)
    return scope if params[:diy_kit].blank?

    diy_kit = params[:diy_kit] == '1'

    scope = scope.left_outer_joins(:product_variants)
    scope.where(product_variants: { diy_kit: diy_kit }).or(scope.where(diy_kit: diy_kit))
  end

  def apply_custom_attributes_filter(scope, params)
    return scope if params[:attr].blank?

    relevant_ids = params[:attr].keys.map(&:to_i)
    CustomAttribute.where(id: relevant_ids).find_each do |custom_attribute|
      id_s = custom_attribute.id.to_s
      next if params[:attr][id_s].blank?

      scope = scope.where('custom_attributes ->> ? IN (?)', id_s, params[:attr][id_s])
    end
    scope
  end

  def apply_search_filter(scope, params)
    return scope if params[:query].blank?

    query = "%#{params[:query].strip}%"
    scope.left_outer_joins(:product_variants)
         .where('product_variants.name ILIKE ?', query)
         .or(scope.where('products.name ILIKE ?', query))
  end

  def apply_ordering(scope, params)
    order = case params[:sort]
            when 'name_desc' then 'lower_name DESC'
            when 'release_date_asc'
              'products.release_year ASC NULLS LAST,
               products.release_month ASC NULLS LAST,
               products.release_day ASC NULLS LAST,
               lower_name'
            when 'release_date_desc'
              'products.release_year DESC NULLS LAST,
               products.release_month DESC NULLS LAST,
               products.release_day DESC NULLS LAST,
               lower_name'
            else 'lower_name ASC'
            end
    scope.order(order)
  end
end
