# frozen_string_literal: true

require 'test_helper'

class ProductsHelperTest < ActionView::TestCase
  test 'sub_category_links lists each sub-category with catalogue query params' do
    product = Product.includes(:sub_categories).find(products(:one).id)

    html = sub_category_links(product)

    product.sub_categories.each do |sub|
      assert_includes html, sub.name
      assert_includes html, sub.friendly_id
    end
  end
end
