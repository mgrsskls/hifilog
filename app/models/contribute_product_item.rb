# frozen_string_literal: true

# Scenic row for contribute incomplete-product queues. Carries completeness / specs_*
# (and the highlighted-specs LATERAL that computes them). Catalogue listings use ProductItem.
class ContributeProductItem < ApplicationRecord
  include CatalogueProductRow

  scope :missing_release_year, -> { where(release_year: nil) }
  # The view's `description` is always the parent product's, so a variant row needs its own
  # column here. Otherwise a variant with no description of its own is never listed, even though
  # its completeness score — which uses the variant's own description — counts it as missing.
  scope :missing_description, lambda {
    where(item_type: 'Product', description: nil)
      .or(where(item_type: 'ProductVariant', variant_description: nil))
  }
  scope :missing_discontinued_year, -> { where(discontinued_year: nil, discontinued: true) }
  scope :missing_specs, lambda {
    where(
      'contribute_product_items.specs_applicable > 0 AND ' \
      'contribute_product_items.specs_filled < contribute_product_items.specs_applicable'
    )
  }
  scope :incomplete, -> { where('contribute_product_items.completeness < 100') }
end
