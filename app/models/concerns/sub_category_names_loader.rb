# frozen_string_literal: true

# Batches the sub_category_names lookup for a page of catalogue rows (ProductItem /
# ContributeProductItem) instead of running it once per row.
#
# Both scenic views dropped their per-row sub_category_names subquery (it ran once for every row
# matching the filter, not just the ones displayed). This loads it for just the current page
# instead, same shape as CatalogueProductRow.preload_list_possession_images.
module SubCategoryNamesLoader
  extend ActiveSupport::Concern

  class_methods do
    # The query is deferred rather than run now: shared/_products_table renders every row through
    # a fragment cache, and sub_category_names is only read inside that cache block. On a fully
    # cached page nothing asks for the names and no query runs at all; on the first miss, one
    # query covers the whole page.
    def preload_sub_category_names(relation)
      records = relation.records
      return relation if records.empty?

      names_by_product_id = nil
      loader = lambda do
        names_by_product_id ||= SubCategory.joins(:products)
                                           .where(products: { id: records.map(&:product_id) })
                                           .pluck('products.id', :name)
                                           .group_by(&:first)
                                           .transform_values { |rows| rows.map(&:last) }
      end
      records.each { |record| record.sub_category_names_loader = loader }

      relation
    end
  end

  attr_writer :sub_category_names_loader

  # Deliberately raises instead of returning [] when the preload was skipped. The names are no
  # longer a column, so a missed preload would otherwise render an empty category badge — a
  # silent wrong answer on a page that looks fine. Every caller of shared/_products_table must
  # run the preload; ContributeControllerTest asserts the badge actually reaches the markup.
  def sub_category_names
    unless @sub_category_names_loader
      raise "#{self.class.name}#sub_category_names was read without a preload — " \
            "call #{self.class.name}.preload_sub_category_names(relation) first"
    end

    @sub_category_names ||= @sub_category_names_loader.call[product_id] || []
  end
end
