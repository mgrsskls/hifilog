# frozen_string_literal: true

# "Related Products" on catalogue detail pages: the companions a product is compatible with, drawn
# from a hand-authored role graph and gated on custom attributes. Design: docs/pairing-graph.md.
#
# Resolver decides WHICH sub categories may appear and what their candidates must satisfy; Query
# fetches and orders them. Both are pure reads and neither caches: the gates ride the existing
# GIN index on products.custom_attributes, and a cached block would have to be invalidated by any
# edit to any product in a target sub category.
module RelatedProducts
  def self.for(product:, product_variant: nil)
    targets = Resolver.new(product:, product_variant:).call
    return [] if targets.empty?

    Query.new(product:, product_variant:, targets:).call
  end
end
