# frozen_string_literal: true

# Working surfaces for contributors: lists of entries with a known, specific gap.
#
# These are deliberately noindex — they are a task board, not content. They are also read-only;
# every link leads into the existing brand / product edit forms.
class ContributeController < ApplicationController
  include ApplicationHelper

  BRAND_MISSING_FILTERS = %w[founded_year description country_code discontinued discontinued_year website].freeze
  PRODUCT_MISSING_FILTERS = %w[release_year description discontinued_year specs].freeze

  BRAND_ORDER = 'brands.completeness DESC, brands.created_at DESC, LOWER(brands.name)'
  PRODUCT_ORDER = 'product_items.completeness DESC, product_items.created_at DESC, LOWER(product_items.name)'

  before_action :set_active_menu
  before_action :set_noindex_meta_robots
  before_action :set_category

  def index
    page_title(t('.heading'))
  end

  def brands_without_products
    page_title(t('.heading'))

    brands = filter_brands_by_category(Brand.without_products).order(Arel.sql(BRAND_ORDER))

    @brands = brands.with_attached_logo.page(params[:page])
    @brands = brands.with_attached_logo.page(1) if @brands.out_of_range?
    @product_counts = @brands.to_h { |brand| [brand.id, 0] }
  end

  def incomplete_brands
    page_title(t('.heading'))

    @missing = params[:missing].presence_in(BRAND_MISSING_FILTERS)

    items = filter_brands_by_category(scope_for_brand_missing(@missing)).order(Arel.sql(BRAND_ORDER))

    @brands = items.page(params[:page])
    @brands = items.page(1) if @brands.out_of_range?
    @product_counts = @brands.to_h do |brand|
      [
        brand.id,
        brand.products_count
      ]
    end
  end

  def incomplete_products
    page_title(t('.heading'))

    @missing = params[:missing].presence_in(PRODUCT_MISSING_FILTERS)

    items = filter_products_by_category(scope_for_product_missing(@missing)).order(Arel.sql(PRODUCT_ORDER))

    @products = items.includes(:brand).page(params[:page])
    @products = items.includes(:brand).page(1) if @products.out_of_range?
    @products = ProductItem.preload_list_possession_images(@products)
  end

  private

  def scope_for_brand_missing(missing)
    case missing
    when 'founded_year' then Brand.missing_founded_year
    when 'description' then Brand.missing_description
    when 'country_code' then Brand.missing_country_code
    when 'discontinued' then Brand.missing_discontinued
    when 'discontinued_year' then Brand.missing_discontinued_year
    when 'website' then Brand.missing_website
    else Brand.incomplete
    end
  end

  def scope_for_product_missing(missing)
    case missing
    when 'release_year' then ProductItem.missing_release_year
    when 'description' then ProductItem.missing_description
    when 'discontinued_year' then ProductItem.missing_discontinued_year
    when 'specs' then ProductItem.missing_specs
    else ProductItem.incomplete
    end
  end

  # Subqueries rather than joins, so paging and ordering are not affected by duplicate rows from
  # the category join.
  def filter_brands_by_category(scope)
    return scope if @category.blank?

    scope.where(
      id: Brand.joins(sub_categories: :category).where(categories: { id: @category.id }).select(:id)
    )
  end

  def filter_products_by_category(scope)
    return scope if @category.blank?

    scope.where(
      product_id: Product.joins(sub_categories: :category)
                         .where(categories: { id: @category.id })
                         .select(:id)
    )
  end

  def set_category
    slug = params[:category].presence

    @category = slug ? Category.friendly.find(slug) : nil
  end

  def set_active_menu
    @active_menu = :contribute
  end

  def set_noindex_meta_robots
    @meta_robots = 'noindex, follow'
  end
end
