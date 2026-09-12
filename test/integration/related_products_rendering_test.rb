# frozen_string_literal: true

require 'test_helper'

# The block as rendered. Product and variant show pages both go through ProductCatalogShow.
class RelatedProductsRenderingTest < ActionDispatch::IntegrationTest
  test 'a tube amplifier page lists driver tubes' do
    get product_path(id: products(:tube_headphone_amp).friendly_id)

    assert_response :success
    assert_select 'h2', text: I18n.t('related_products.heading')
    assert_select '.Product-section--relatedProducts', text: /Driver Tube/
  end

  test 'a solid state amplifier page does not list driver tubes' do
    get product_path(id: products(:solid_state_headphone_amp).friendly_id)

    assert_response :success
    assert_select '.Product-section--relatedProducts' do
      assert_select 'a', text: /Driver Tube/, count: 0
    end
  end

  test 'the block is absent when nothing resolves' do
    # A headphone with no connection type falls back to a common edge whose sub category the
    # fixture catalogue lacks, so the section renders nothing at all rather than an empty heading.
    get product_path(id: products(:two).friendly_id)

    assert_response :success
    assert_select '.Product-section--relatedProducts', count: 0
  end

  test 'a group is headed by its own sub category, linking to that index' do
    # Groups are labelled by the sub category their items are in, never by the role that selected
    # them -- a role heading could only link up to a whole category.
    get product_path(id: products(:tube_headphone_amp).friendly_id)

    assert_select '.Product-section--relatedProducts h3 a[href=?]',
                  products_subcategory_path(category_slug: 'vacuum-tubes',
                                            sub_category_slug: 'pre-amp-driver-tubes'),
                  text: sub_categories(:three).name
  end

  test 'a variant page renders the block from its parent product' do
    variant = product_variants(:one)

    get product_variant_path(product_id: variant.product.friendly_id, id: variant.friendly_id)

    assert_response :success
  end
end
