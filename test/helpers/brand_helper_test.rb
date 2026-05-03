# frozen_string_literal: true

require 'test_helper'

class BrandHelperTest < ActionView::TestCase
  test 'brand_products_path_with_filter passes category slug and merges extra filters' do
    brand = brands(:one)
    category = categories(:one)

    path = brand_products_path_with_filter(brand, category, nil, diy_kit: '1')

    assert_includes path, brand.friendly_id.to_s
    assert_includes path, categories(:one).friendly_id.to_s
    assert_match(/diy_kit=1/, path)
  end

  test 'brand_products_path_with_filter encodes sub category constraint' do
    brand = brands(:one)
    category = categories(:one)
    sub_category = sub_categories(:one)

    path = brand_products_path_with_filter(brand, category, sub_category, {})

    assert_includes path, brand.friendly_id.to_s
    assert_match(/category=/, path)
    assert_includes path, sub_category.friendly_id.to_s
  end
end
