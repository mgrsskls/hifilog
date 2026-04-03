# frozen_string_literal: true

module ProductsHelper
  def sub_category_links(product)
    links = product.sub_categories.map do |sub_category|
      link_to sub_category.name, products_path(sub_category: sub_category.friendly_id)
    end

    safe_join(links, ', ')
  end
end
