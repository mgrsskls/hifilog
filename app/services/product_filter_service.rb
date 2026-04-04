# frozen_string_literal: true

class ProductFilterService
  include FilterConstants
  include FilterableService

  Result = Struct.new(:products)

  def initialize(filters: {}, brand_filters: {}, brands: [], category: nil, sub_category: nil)
    @filters = filters
    @category = category
    @sub_category = sub_category
    @products = brands.any? ? ProductItem.where(brand_id: brands.map(&:id)) : ProductItem.all
    @brand_filters = brand_filters
  end

  def filter
    products = @products

    if @sub_category || @category
      if @sub_category
        matching_sub_categories = products.where(
          id: ProductItem.joins(
            'INNER JOIN products_sub_categories ON products_sub_categories.product_id = product_items.product_id'
          )
              .where(products_sub_categories: { sub_category_id: @sub_category.id })
              .select(:id)
        )
      else
        matching_sub_categories = products.where(
          id: ProductItem.joins(
            'INNER JOIN products_sub_categories ON products_sub_categories.product_id = product_items.product_id'
          )
              .joins('INNER JOIN sub_categories ON sub_categories.id = products_sub_categories.sub_category_id')
                         .where(sub_categories: { category_id: @category.id })
                         .select(:id)
        )
      end
      products = matching_sub_categories
    end

    data = {
      sort: @filters[:sort],
      status: @filters[:status],
      country: @filters[:country],
      diy_kit: @filters[:diy_kit],
      query: @filters[:query],
      custom_attributes: @filters[:custom]
    }

    products = apply_ordering(products, data)
    products = apply_status_filter(products, data) if data[:status].present?
    products = apply_country_filter(products, data) if data[:country].present?
    products = apply_diy_kit_filter(products, data) if data[:diy_kit].present?
    products = apply_search_filter(products, data) if data[:query].present?
    products = apply_custom_filters(products, data) if data[:custom_attributes].present?

    if @brand_filters.present?
      brands_scope = Brand.where(id: products.select(:brand_id))

      brand_ids_from_brand_filter = BrandFilterService.new(
        filters: @brand_filters,
        brands: brands_scope
      ).filter.brands.select(:id)

      products = products.where(brand_id: brand_ids_from_brand_filter)
    end

    Result.new(products:)
  end

  private

  def apply_status_filter(scope, options)
    discontinued = options[:status] == 'discontinued'

    scope.where(discontinued:)
  end

  def apply_country_filter(scope, options)
    scope.joins(:brand).where(brand: { country_code: options[:country].strip.upcase })
  end

  def apply_diy_kit_filter(scope, options)
    scope.where(diy_kit: options[:diy_kit] == '1')
  end

  def apply_search_filter(scope, options)
    scope.search_by_name("%#{options[:query].strip}%")
  end

  def apply_custom_filters(scope, options)
    custom_attributes = options[:custom_attributes]
    custom_attribute_records = CustomAttribute.where(label: custom_attributes.deep_dup.to_hash.pluck(0))

    custom_attributes.each do |param|
      custom_attribute = custom_attribute_records.detect { |record| record.label == param.first }
      value = param[1]

      next if custom_attribute.blank?
      next if value.blank?

      label = custom_attribute[:label]

      scope = case custom_attribute[:input_type]
              when 'number'
                filter_scope_by_numeric_custom_attribute(scope, custom_attribute, value)
              when 'boolean'
                scope.where('(custom_attributes ->> :label) = (:value)', label: label,
                                                                         value: value == '1' ? 'true' : 'false')
              when 'option'
                scope.where('(custom_attributes ->> :label IN (:values))', label: label, values: value)
              when 'options'
                scope.where('(custom_attributes -> :label ?| array[:values])', label: label, values: value)
              end
    end

    scope
  end

  def apply_ordering(scope, options)
    order = case options[:sort]&.downcase
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
            when 'added_asc' then 'created_at ASC'
            when 'added_desc' then 'created_at DESC'
            when 'updated_asc' then 'updated_at ASC'
            when 'updated_desc' then 'updated_at DESC'
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
    inputs = custom_attribute[:inputs]
    label = custom_attribute[:label]
    param_unit = param[:unit]

    if inputs.present?
      inputs.each do |input|
        param_input = param[input]
        min, max = convert_values(param_unit, param_input[:min], param_input[:max])

        if min.present?
          scope = scope.where(
            '(custom_attributes -> ? -> ? ->> ?)::numeric >= ?',
            label,
            'value',
            input,
            min
          )
        end

        next if max.blank?

        scope = scope.where(
          '(custom_attributes -> ? -> ? ->> ?)::numeric <= ?',
          label,
          'value',
          input,
          max
        )
      end
    else
      min, max = convert_values(param_unit, param[:min], param[:max])

      if min.present?
        scope = scope.where("NULLIF(custom_attributes -> ? ->> ?, '')::numeric >= ?", label, 'value',
                            min)
      end

      if max.present?
        scope = scope.where("NULLIF(custom_attributes -> ? ->> ?, '')::numeric <= ?", label, 'value',
                            max)
      end
    end

    if custom_attribute[:units].present? && param_unit.present?
      unit = convert_unit(param_unit)
      scope = scope.where('custom_attributes -> ? ->> ? = ?', label, 'unit', unit)
    end

    scope
  end
end
