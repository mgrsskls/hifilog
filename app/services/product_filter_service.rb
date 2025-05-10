# frozen_string_literal: true

class ProductFilterService
  include FilterConstants
  include FilterableService

  Result = Struct.new(:products, keyword_init: true)

  def initialize(filters, brand, category = nil, sub_category = nil)
    @filters = filters
    @category = category
    @sub_category = sub_category
    @products = brand.present? ? brand.products : Product.all
  end

  def filter
    products = @products

    if @sub_category
      products = products.joins(:sub_categories).where(sub_categories: { id: @sub_category.id })
    elsif @category
      products = products.joins(:sub_categories).where(sub_categories: { category_id: @category.id })
    end

    products = apply_ordering(products, @filters[:sort])
    products = apply_letter_filter(products, @filters[:letter], 'products.name') if @filters[:letter].present?
    products = apply_status_filter(products, @filters[:status]) if @filters[:status].present?
    products = apply_country_filter(products, @filters[:country]) if @filters[:country].present?
    products = apply_diy_kit_filter(products, @filters[:diy_kit]) if @filters[:diy_kit].present?
    products = apply_custom_attributes_filter(products, @filters[:attr]) if @filters[:attr].present?
    products = apply_search_filter(products, @filters[:query]) if @filters[:query].present?
    products = products.select('products.*, LOWER(products.name)').distinct
    Result.new(products:)
  end

  private

  def apply_status_filter(scope, value)
    discontinued = value == 'discontinued'

    scope.left_joins(:product_variants)
         .where(product_variants: { discontinued: })
         .or(scope.where(discontinued:))
  end

  def apply_country_filter(scope, value)
    scope.joins(:brand).where(brand: { country_code: value.strip.upcase })
  end

  def apply_diy_kit_filter(scope, value)
    diy_kit = value == '1'

    scope = scope.left_joins(:product_variants)
    scope.where(product_variants: { diy_kit: diy_kit }).or(scope.where(diy_kit: diy_kit))
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

    scope = scope.left_joins(:product_variants)
    scope.where('product_variants.name ILIKE ?', query).or(scope.where('products.name ILIKE ?', query))
  end

  def apply_ordering(scope, value)
    order = case value&.downcase
            when 'name_desc' then 'LOWER(products.name) DESC'
            when 'release_date_asc'
              'products.release_year ASC NULLS LAST,
               products.release_month ASC NULLS LAST,
               products.release_day ASC NULLS LAST,
               LOWER(products.name)'
            when 'release_date_desc'
              'products.release_year DESC NULLS LAST,
               products.release_month DESC NULLS LAST,
               products.release_day DESC NULLS LAST,
               LOWER(products.name)'
            else 'LOWER(products.name) ASC'
            end
    scope.order(order)
  end
end
