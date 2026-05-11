# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module ProductsHelper
  def products_index_item_list_json_ld(products:)
    product_items_item_list_json_ld(products:, name: products_index_item_list_name)
  end

  def product_show_json_ld(product:, meta_desc:, image_urls: nil)
    data = {
      '@context' => 'https://schema.org',
      '@type' => 'Product',
      'name' => product.display_name,
      'url' => product_url(id: product.friendly_id)
    }

    data['description'] = meta_desc.squish if meta_desc.present?

    brand_payload = schema_org_brand(product)
    data['brand'] = brand_payload if brand_payload

    urls = Array(image_urls).compact_blank
    if urls.size == 1
      data['image'] = urls.first
    elsif urls.size > 1
      data['image'] = urls
    end

    data['releaseDate'] = product.release_date.iso8601 if product.release_date.present?

    category_names = product.sub_categories.map(&:name).uniq
    data['category'] = category_names.join(', ') if category_names.any?

    data
  end

  def product_show_schema_image_urls(images)
    Array(images).filter_map do |image|
      schema_absolute_uri(cdn_image_url(image.variant(:large)))
    end
  end

  def brand_products_item_list_json_ld(brand:, meta_desc:, products:)
    product_items_item_list_json_ld(
      products:,
      name: brand_products_item_list_name(brand:),
      description: meta_desc
    )
  end

  def sub_category_links(product)
    links = product.sub_categories.map do |sub_category|
      link_to sub_category.name, products_path(sub_category: sub_category.friendly_id)
    end

    safe_join(links, ', ')
  end

  private

  def product_items_item_list_json_ld(products:, name:, description: nil)
    schema_org_item_list(
      name:,
      url: request.original_url,
      description:,
      item_list_order: products_index_item_list_order,
      item_list_elements: products.each_with_index.map do |item, index|
        list_item_for_product_item(products, item, index)
      end
    )
  end

  def brand_products_item_list_name(brand:)
    "#{brand.name} #{Product.model_name.human.pluralize}"
  end

  def products_index_item_list_name
    if current_sub_category.present?
      current_sub_category.name
    elsif current_category.present?
      current_category.name
    else
      Product.model_name.human.pluralize
    end
  end

  def products_index_item_list_order
    sort = params[:sort].presence || 'name_asc'

    schema_item_list_order(
      sort,
      ascending: %w[name_asc release_date_asc added_asc updated_asc],
      descending: %w[name_desc release_date_desc added_desc updated_desc]
    )
  end

  def list_item_for_product_item(products, product_item, index)
    {
      '@type' => 'ListItem',
      'position' => schema_item_list_position(products, index),
      'item' => schema_org_product(product_item)
    }
  end

  def schema_org_product(product_item)
    presenter = ProductItemPresenter.new(product_item, false)
    payload = {
      '@type' => 'Product',
      'name' => presenter.display_name,
      'url' => product_item_schema_url(product_item)
    }

    brand_payload = schema_org_brand(product_item)
    payload['brand'] = brand_payload if brand_payload

    payload['sku'] = product_item.model_no if product_item.model_no.present?

    payload
  end

  def schema_org_brand(product_item)
    if product_item.brand
      {
        '@type' => 'Brand',
        'name' => product_item.brand.name,
        'url' => brand_url(product_item.brand)
      }
    elsif product_item.respond_to?(:brand_name) && product_item.brand_name.present?
      { '@type' => 'Brand', 'name' => product_item.brand_name }
    end
  end

  def product_item_schema_url(product_item)
    if product_item.item_type == 'ProductVariant'
      product_variant_url(id: product_item.variant_slug, product_id: product_item.product_slug)
    else
      product_url(id: product_item.product_slug)
    end
  end
end
# rubocop:enable Metrics/ModuleLength
