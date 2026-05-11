# frozen_string_literal: true

module BreadcrumbsHelper
  EVENTS_INDEX_BREADCRUMB_NAME = 'Hi-Fi Events & Shows'

  def products_catalogue_breadcrumb_json_ld(category:, sub_category:, canonical_url:)
    crumbs = [
      [APP_NAME, root_url],
      [Product.model_name.human.pluralize, products_url]
    ]
    if sub_category.present?
      crumbs << [sub_category.category.name, products_category_url(sub_category.category.friendly_id)]
      crumbs << [sub_category.name, canonical_url]
    elsif category.present?
      crumbs << [category.name, canonical_url]
    else
      crumbs.last[1] = canonical_url
    end
    schema_org_breadcrumb_list(crumbs)
  end

  def brands_catalogue_breadcrumb_json_ld(category:, sub_category:, canonical_url:)
    crumbs = [
      [APP_NAME, root_url],
      [Brand.model_name.human.pluralize, brands_url]
    ]
    if sub_category.present?
      crumbs << [sub_category.category.name, brands_category_url(sub_category.category.friendly_id)]
      crumbs << [sub_category.name, canonical_url]
    elsif category.present?
      crumbs << [category.name, canonical_url]
    else
      crumbs.last[1] = canonical_url
    end
    schema_org_breadcrumb_list(crumbs)
  end

  def brand_show_breadcrumb_json_ld(brand:, canonical_url:)
    schema_org_breadcrumb_list(
      [
        [APP_NAME, root_url],
        [Brand.model_name.human.pluralize, brands_url],
        [brand.name, canonical_url]
      ]
    )
  end

  def brand_products_breadcrumb_json_ld(brand:, category:, sub_category:, canonical_url:)
    crumbs = [
      [APP_NAME, root_url],
      [Brand.model_name.human.pluralize, brands_url],
      [brand.name, brand_url(brand)],
      [Product.model_name.human.pluralize, canonical_url]
    ]
    if sub_category.present?
      crumbs[-1] = [sub_category.category.name,
                    brand_brand_products_category_url(brand, sub_category.category.friendly_id)]
      crumbs << [sub_category.name, canonical_url]
    elsif category.present?
      crumbs[-1] = [category.name, canonical_url]
    end
    schema_org_breadcrumb_list(crumbs)
  end

  def product_show_breadcrumb_json_ld(product:, canonical_url:)
    schema_org_breadcrumb_list(product_detail_breadcrumb_crumbs(product, product.display_name, canonical_url))
  end

  def product_variant_show_breadcrumb_json_ld(product:, product_variant:, canonical_url:)
    name = "#{product_variant.product.display_name} — #{product_variant.name_with_fallback}"
    crumbs = product_detail_breadcrumb_crumbs(product, product.display_name, product_url(id: product.friendly_id))
    crumbs << [name, canonical_url]
    schema_org_breadcrumb_list(crumbs)
  end

  def events_index_breadcrumb_json_ld(active_events:, canonical_url:, selected_year: nil)
    crumbs = [
      [APP_NAME, root_url],
      [EVENTS_INDEX_BREADCRUMB_NAME, events_url]
    ]
    if active_events == :past && selected_year.present?
      crumbs << ["Past (#{selected_year})", canonical_url]
    else
      crumbs.last[1] = canonical_url
    end
    schema_org_breadcrumb_list(crumbs)
  end

  private

  def primary_product_sub_category(product)
    subs = product.sub_categories
    return if subs.blank?

    subs.includes(:category).min_by { |sub| [sub.category.order, sub.category_id, sub.order, sub.id] }
  end

  def product_detail_breadcrumb_crumbs(product, penultimate_name, penultimate_url)
    crumbs = [
      [APP_NAME, root_url],
      [Product.model_name.human.pluralize, products_url]
    ]
    sub = primary_product_sub_category(product)
    if sub
      crumbs << [sub.category.name, products_category_url(sub.category.friendly_id)]
      crumbs << [sub.name, products_subcategory_url(sub.category.friendly_id, sub.friendly_id)]
    elsif product.brand
      crumbs << [product.brand.name, brand_url(product.brand)]
    end
    crumbs << [penultimate_name, penultimate_url]
    crumbs
  end
end
