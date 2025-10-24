# frozen_string_literal: true

class ProductFilterService
  include FilterConstants
  include FilterableService

  Result = Struct.new(:products, keyword_init: true)

  def initialize(filters: {}, brand_filters: {}, brands: [], category: nil, sub_category: nil)
    @filters = filters
    @category = category
    @sub_category = sub_category
    @products = brands.any? ? ProductItem.where(brand_id: brands.map(&:id)) : ProductItem.all
    @brand_filters = brand_filters
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
    products = apply_search_filter(products, @filters[:query]) if @filters[:query].present?
    products = apply_custom_filters(products, @filters[:custom]) if @filters[:custom].present?

    if @brand_filters.present?
      brand_ids_from_brand_filter = BrandFilterService.new(
        filters: @brand_filters,
        brands: Brand.where(id: products.pluck(:brand_id).uniq)
      ).filter.brands.map(&:id)
      products = products.where(brand_id: brand_ids_from_brand_filter)
    end

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

  def apply_search_filter(scope, value)
    query = "%#{value.strip}%"

    scope.search(query)
  end

  def apply_custom_filters(scope, custom_attributes)
    custom_attribute_records = CustomAttribute.where(label: custom_attributes.deep_dup.to_hash.pluck(0))

    custom_attributes.each do |param|
      custom_attribute = custom_attribute_records.select { |record| record.label == param.first }.first

      next if custom_attribute.blank?
      next if param[1].blank?

      label = custom_attribute[:label]

      scope = case custom_attribute[:input_type]
              when 'number'
                filter_scope_by_numeric_custom_attribute(scope, custom_attribute, param[1])
              when 'boolean'
                scope.where('(custom_attributes ->> :label) = (:value)', label: label,
                                                                         value: param[1] == '1' ? 'true' : 'false')
              when 'option'
                scope.where('(custom_attributes ->> :label IN (:values))', label: label, values: param[1])
              when 'options'
                scope.where('(custom_attributes -> :label ?| array[:values])', label: label, values: param[1])
              end
    end

    scope
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

  def convert_values(unit, min, max)
    min = Float(min, exception: false)
    max = Float(max, exception: false)

    case unit
    when 'in'
      min *= 2.54 if min.present?
      max *= 2.54 if max.present?
    when 'lb'
      min *= 0.453592 if min.present?
      max *= 0.453592 if max.present?
    end

    [min, max]
  end

  def convert_unit(unit)
    case unit
    when 'in' then unit = 'cm'
    when 'lb' then unit = 'kg'
    end

    unit
  end

  def filter_scope_by_numeric_custom_attribute(scope, custom_attribute, param)
    if custom_attribute[:inputs].present?
      custom_attribute[:inputs].each do |input|
        min, max = convert_values(param[:unit], param[input][:min], param[input][:max])

        if min.present?
          scope = scope.where(
            '(custom_attributes -> ? -> ? ->> ?)::numeric >= ?',
            custom_attribute[:label],
            'value',
            input,
            min
          )
        end

        next if max.blank?

        scope = scope.where(
          '(custom_attributes -> ? -> ? ->> ?)::numeric <= ?',
          custom_attribute[:label],
          'value',
          input,
          max
        )
      end
    else
      min, max = convert_values(param[:unit], param[:min], param[:max])

      if min.present?
        scope = scope.where('(custom_attributes -> ? ->> ?)::numeric >= ?', custom_attribute[:label], 'value', min)
      end
      if max.present?
        scope = scope.where('(custom_attributes -> ? ->> ?)::numeric <= ?', custom_attribute[:label], 'value', max)
      end
    end

    if custom_attribute[:units].present? && param[:unit].present?
      unit = convert_unit(param[:unit])
      scope = scope.where('custom_attributes -> ? ->> ? = ?', custom_attribute[:label], 'unit', unit)
    end

    scope
  end
end
