# frozen_string_literal: true

# View support for the "Related Products" block (docs/pairing-graph.md).
#
# Groups are labelled and linked by the sub category their items are in, not by the role that
# selected them: a role like `integrated` names no browsable page, so a heading built from it
# could only link up to a whole category and promise gear the group does not contain.
module RelatedProductsHelper
  def related_products_group_heading(group)
    CacheService.sub_category_headings[group.sub_category_id]
  end
end
