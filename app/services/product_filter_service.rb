# frozen_string_literal: true

class ProductFilterService
  include FilterConstants
  include FilterableService

  Result = Struct.new(:products, keyword_init: true)

  def initialize(filters, brands, category = nil, sub_category = nil)
    @filters = filters
    @category = category
    @sub_category = sub_category
    @products = brands.any? ? ProductItem.where(brand_id: brands.map(&:id)) : ProductItem.all
  end

  def filter
    products = @products

    if @sub_category
      products = products.joins(
        'LEFT JOIN products_sub_categories ON products_sub_categories.product_id = product_items.product_id'
      ).where(products_sub_categories: { sub_category_id: @sub_category.id })
    elsif @category
      products = products.joins(
        'LEFT JOIN products_sub_categories ON products_sub_categories.product_id = product_items.product_id'
      ).joins(
        'LEFT JOIN sub_categories ON sub_categories.id = products_sub_categories.sub_category_id'
      ).where(sub_categories: { category_id: @category.id })
    end

    products = apply_ordering(products, @filters[:sort])
    products = apply_status_filter(products, @filters[:status]) if @filters[:status].present?
    products = apply_country_filter(products, @filters[:country]) if @filters[:country].present?
    products = apply_diy_kit_filter(products, @filters[:diy_kit]) if @filters[:diy_kit].present?
    products = apply_custom_attributes_filter(products, @filters[:attr]) if @filters[:attr].present?
    products = apply_search_filter(products, @filters[:query]) if @filters[:query].present?
    Result.new(products:)
  end

  private

  def apply_status_filter(scope, value)
    discontinued = value == 'discontinued'

    scope.where(discontinued:)
  end

  def apply_country_filter(scope, value)
    scope.joins(:brand).where(brand: { country_code: value.strip.upcase })
  end

  def apply_diy_kit_filter(scope, value)
    diy_kit = value == '1'

    scope.where(diy_kit: diy_kit)
  end

  def apply_custom_attributes_filter(scope, value)
    relevant_ids = value.keys.map(&:to_i)
    CustomAttribute.where(id: relevant_ids).find_each do |custom_attribute|
      id_s = custom_attribute.id.to_s
      next if value[id_s].blank?

      scope = scope.where('custom_attributes ->> ? IN (?)', id_s, value[id_s])
    end
    scope
  end

  def apply_search_filter(scope, value)
    query = "%#{value.strip}%"

    scope.where('product_items.name ILIKE ?', query)
         .or(scope.where('model_no ILIKE ?', query))
  end

  def apply_ordering(scope, value)
    order = case value&.downcase
            when 'name_desc'
              'LOWER(product_items.name) DESC,
               release_year ASC NULLS FIRST,
               release_month ASC NULLS FIRST,
               release_day ASC NULLS FIRST'
            when 'release_date_asc'
              'release_year ASC NULLS LAST,
               release_month ASC NULLS LAST,
               release_day ASC NULLS LAST,
               LOWER(product_items.name)'
            when 'release_date_desc'
              'release_year DESC NULLS LAST,
               release_month DESC NULLS LAST,
               release_day DESC NULLS LAST,
               LOWER(product_items.name)'
            else 'LOWER(product_items.name) ASC,
                  release_year ASC NULLS FIRST,
                  release_month ASC NULLS FIRST,
                  release_day ASC NULLS FIRST'
            end
    scope.order(order)
  end
end
