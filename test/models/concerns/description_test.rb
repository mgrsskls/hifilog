# frozen_string_literal: true

require 'test_helper'

class DescriptionTest < ActiveSupport::TestCase
  test 'markdown converts to HTML with allowed tags enforced' do
    product = Product.new
    fragment = '**Bold** plus <script>nope</script>'

    html = product.markdown_to_safe_html(fragment)

    assert_includes html, 'Bold'
    assert_no_match(/<script/i, html)
  end

  test 'formatted_description prefers persisted description markdown' do
    product = products(:two)
    product.assign_attributes(description: '**wired** headphone')

    assert_includes product.formatted_description.downcase, 'wired'
    assert_predicate product.description, :present?
  end

  test 'fallback_description complements Description when overridden' do
    brand = brands(:one)
    brand.update!(description: nil)

    assert_predicate brand.reload.formatted_description, :present?
  end
end
