# frozen_string_literal: true

module BrandHelper
  def brands_index_item_list_json_ld(brands:, meta_desc:, category: nil, sub_category: nil)
    brands_catalogue_item_list_json_ld(
      brands:,
      meta_desc:,
      name: brands_index_item_list_name(category:, sub_category:)
    )
  end

  def brand_show_json_ld(brand:, meta_desc:)
    data = {
      '@context' => 'https://schema.org',
      '@type' => 'Brand',
      'name' => brand.name,
      'url' => brand_url(brand)
    }

    data['alternateName'] = brand.full_name if brand.full_name.present?
    data['description'] = meta_desc.squish if meta_desc.present?

    data['logo'] = schema_absolute_uri(cdn_image_url(brand.logo.variant(:thumb))) if brand.logo.attached?

    website = brand_show_schema_website_uri(brand.website)
    data['sameAs'] = [website] if website.present?

    data
  end

  def brand_products_path_with_filter(brand, category, sub_category, products = {})
    extra = products.respond_to?(:to_unsafe_h) ? products.to_unsafe_h : products.to_h
    if sub_category.present?
      brand_brand_products_subcategory_path(brand,
                                            sub_category.category.friendly_id,
                                            sub_category.friendly_id,
                                            **extra)
    elsif category.present?
      brand_brand_products_category_path(brand, category.friendly_id, **extra)
    else
      brand_products_path(brand.friendly_id, **extra)
    end
  end

  private

  def brands_catalogue_item_list_json_ld(brands:, meta_desc:, name:)
    schema_org_item_list(
      name:,
      url: request.original_url,
      description: meta_desc,
      item_list_order: brands_index_item_list_order,
      item_list_elements: brands.each_with_index.map { |brand, index| list_item_for_brands_index(brands, brand, index) }
    )
  end

  def brands_index_item_list_name(category:, sub_category:)
    if sub_category.present?
      sub_category.name
    elsif category.present?
      category.name
    else
      Brand.model_name.human.pluralize
    end
  end

  def brands_index_item_list_order
    sort = params[:sort].presence || 'name_asc'

    schema_item_list_order(
      sort,
      ascending: %w[name_asc products_asc added_asc updated_asc],
      descending: %w[name_desc products_desc added_desc updated_desc]
    )
  end

  def list_item_for_brands_index(brands, brand, index)
    {
      '@type' => 'ListItem',
      'position' => schema_item_list_position(brands, index),
      'item' => schema_org_brand_list_item(brand)
    }
  end

  def schema_org_brand_list_item(brand)
    {
      '@type' => 'Brand',
      'name' => brand.name,
      'url' => brand_url(brand)
    }
  end

  def brand_show_schema_website_uri(website)
    return if website.blank?

    w = website.to_s.strip
    return if w.match?(/\A[a-z][a-z0-9+\-.]*:/i) && !w.match?(%r{\Ahttps?://}i)

    uri = URI.parse(w.match?(%r{\Ahttps?://}i) ? w : "https://#{w}")
    return unless uri.host.present? && uri.host.include?('.')

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end
end
