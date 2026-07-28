# frozen_string_literal: true

class ProductFilterService
  include FilterConstants
  include FilterableService

  Result = Struct.new(:products)

  def initialize(filters: {}, brand_filters: {}, brands: [], category: nil, sub_category: nil)
    @filters = filters
    @category = category
    @sub_category = sub_category
    @brands = brands
    @products = products_scope_for(brands)
    @brand_filters = brand_filters
  end

  def filter
    products = @products

    if @sub_category
      products = products.joins(
        'INNER JOIN products_sub_categories ON products_sub_categories.product_id = product_items.product_id'
      ).where(products_sub_categories: { sub_category_id: @sub_category.id })
    elsif @category
      # product_id avoids duplicate rows when a product has multiple sub-categories in the category
      products = products.where(
        product_id: Product.joins(:sub_categories)
                           .where(sub_categories: { category_id: @category.id })
                           .select(:id)
      )
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
      # ORDER BY is irrelevant inside these IN (...) subqueries and forces Postgres to
      # sort the full product_items/brands tables for no reason — strip it (see
      # products_scope_for/resolved_brand_ids below for the same pattern).
      brands_scope = Brand.where(id: products.except(:order).select(:brand_id))

      brand_ids_from_brand_filter = BrandFilterService.new(
        filters: @brand_filters,
        brands: brands_scope
      ).filter.brands.except(:order).select(:id)

      products = products.where(brand_id: brand_ids_from_brand_filter)
    end

    Result.new(products:)
  end

  # Counts matching product_items (products + variants) per brand_id.
  # Prefer base tables when product-level filters are absent so we avoid scanning the
  # product_items view (and its completeness LATERAL) for brands#index badges.
  def counts_by_brand
    if base_table_counts_eligible?
      counts_by_brand_on_base_tables
    else
      filter.products.except(:order).group(:brand_id).count
    end
  end

  private

  def base_table_counts_eligible?
    @brand_filters.blank? &&
      @filters[:query].blank? &&
      @filters[:custom].blank?
  end

  def counts_by_brand_on_base_tables
    brand_ids = resolved_brand_ids
    return {} if brand_ids == []

    products = Product.all
    products = products.where(brand_id: brand_ids) unless brand_ids.nil?
    products = scope_products_by_taxonomy(products)
    products = apply_base_table_filters(products)

    variants = ProductVariant.joins(:product)
    variants = variants.where(products: { brand_id: brand_ids }) unless brand_ids.nil?
    variants = scope_variants_by_taxonomy(variants)
    variants = apply_base_table_filters(variants, variants: true)

    counts = Hash.new(0)
    products.group(:brand_id).count.each { |brand_id, count| counts[brand_id] += count }
    variants.group('products.brand_id').count.each { |brand_id, count| counts[brand_id] += count }
    counts
  end

  def apply_base_table_filters(scope, variants: false)
    scope = scope.where(discontinued: @filters[:status] == 'discontinued') if @filters[:status].present?
    scope = scope.where(diy_kit: @filters[:diy_kit] == '1') if @filters[:diy_kit].present?

    if @filters[:country].present?
      scope = variants ? scope.joins(product: :brand) : scope.joins(:brand)
      scope = scope.where(brands: { country_code: @filters[:country].strip.upcase })
    end

    scope
  end

  def scope_products_by_taxonomy(products)
    if @sub_category
      products.joins(:sub_categories).where(sub_categories: { id: @sub_category.id })
    elsif @category
      products.where(
        id: Product.joins(:sub_categories)
                   .where(sub_categories: { category_id: @category.id })
                   .select(:id)
      )
    else
      products
    end
  end

  def scope_variants_by_taxonomy(variants)
    if @sub_category
      variants.joins(product: :sub_categories).where(sub_categories: { id: @sub_category.id })
    elsif @category
      variants.where(
        product_id: Product.joins(:sub_categories)
                           .where(sub_categories: { category_id: @category.id })
                           .select(:id)
      )
    else
      variants
    end
  end

  # nil = no brand restriction; [] = explicitly empty page of brands.
  def resolved_brand_ids
    brands = @brands

    if brands.is_a?(ActiveRecord::Relation)
      scope = brands.reselect(brands.klass.arel_table[:id])
      scope = scope.except(:order) if brands.limit_value.nil? && brands.offset_value.nil?
      scope.pluck(:id)
    elsif brands.present?
      brands.map { |brand| brand.is_a?(ApplicationRecord) ? brand.id : brand }
    end
  end

  def products_scope_for(brands)
    if brands.is_a?(ActiveRecord::Relation)
      # Reselect id so pg_search rank columns do not break `IN (SELECT …)`.
      # Keep ORDER BY when LIMIT/OFFSET are present — otherwise the limited subquery
      # returns an arbitrary set of brands, not the same page as the outer query.
      brand_ids = brands.reselect(brands.klass.arel_table[:id])
      brand_ids = brand_ids.except(:order) if brands.limit_value.nil? && brands.offset_value.nil?
      ProductItem.where(brand_id: brand_ids)
    elsif brands.present?
      ids = brands.map { |brand| brand.is_a?(ApplicationRecord) ? brand.id : brand }
      ProductItem.where(brand_id: ids)
    else
      ProductItem.all
    end
  end

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
            when 'completeness_asc'
              'product_items.completeness ASC, product_items.created_at DESC, LOWER(product_items.name)'
            when 'completeness_desc'
              'product_items.completeness DESC, product_items.created_at DESC, LOWER(product_items.name)'
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
