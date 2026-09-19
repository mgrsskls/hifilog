# frozen_string_literal: true

# Structured data and small display helpers for product series. See docs/product-series.md.
module ProductSeriesHelper
  def product_series_breadcrumb_json_ld(series:, canonical_url:)
    schema_org_breadcrumb_list(
      [
        [APP_NAME, root_url],
        [Brand.model_name.human.pluralize, brands_url],
        [series.brand.display_name, brand_url(series.brand)],
        [series.name, canonical_url]
      ]
    )
  end

  def product_series_item_list_json_ld(series:, products:, canonical_url: nil)
    product_items_item_list_json_ld(
      products:,
      name: series.display_label,
      description: series.meta_desc,
      canonical_url:
    )
  end

  # The linked series line under the product and variant <h1>: "Evolution series".
  def product_series_subline(product)
    series = product.product_series
    return if series.nil?

    tag.p(class: 'Heading-subline') do
      link_to(series.label, series.path)
    end
  end
end
