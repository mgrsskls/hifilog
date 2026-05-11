# frozen_string_literal: true

module StructuredDataHelper
  ITEM_LIST_ORDER_ASCENDING = 'https://schema.org/ItemListOrderAscending'
  ITEM_LIST_ORDER_DESCENDING = 'https://schema.org/ItemListOrderDescending'
  ITEM_LIST_ORDER_UNORDERED = 'https://schema.org/ItemListOrderUnordered'

  def schema_org_item_list(name:, url:, item_list_elements:, description: nil, item_list_order: nil)
    {
      '@context' => 'https://schema.org',
      '@type' => 'ItemList',
      'name' => name,
      'url' => url,
      'numberOfItems' => item_list_elements.size,
      'itemListElement' => item_list_elements
    }.tap do |h|
      h['itemListOrder'] = item_list_order if item_list_order.present?
      h['description'] = description.squish if description.present?
    end
  end

  def schema_item_list_order(sort, ascending:, descending:)
    case sort.to_s
    when *ascending
      ITEM_LIST_ORDER_ASCENDING
    when *descending
      ITEM_LIST_ORDER_DESCENDING
    else
      ITEM_LIST_ORDER_UNORDERED
    end
  end

  def schema_item_list_position(collection, index)
    offset = collection.respond_to?(:offset_value) ? collection.offset_value.to_i : 0

    offset + index + 1
  end

  def schema_org_breadcrumb_list(crumbs)
    # crumbs: array of [name, absolute_url] pairs
    {
      '@context' => 'https://schema.org',
      '@type' => 'BreadcrumbList',
      'itemListElement' => crumbs.each_with_index.map do |(name, url), index|
        {
          '@type' => 'ListItem',
          'position' => index + 1,
          'name' => name,
          'item' => url
        }
      end
    }
  end

  def json_ld_script_tag(json_ld_hash)
    # rubocop:disable Rails/OutputSafety -- JSON-LD built server-side; json_escape makes script embedding safe
    content_tag(:script, json_escape(json_ld_hash.to_json).html_safe, type: 'application/ld+json')
    # rubocop:enable Rails/OutputSafety
  end

  def schema_absolute_uri(href)
    return if href.blank?

    href = href.to_s.strip
    return href if href.match?(%r{\Ahttps?://}i)

    URI.join("#{request.base_url}/", href.delete_prefix('/')).to_s
  end
end
