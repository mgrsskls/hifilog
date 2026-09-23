# frozen_string_literal: true

require 'test_helper'

class GuidelinesHelperTest < ActionView::TestCase
  test 'guideline_path links to the dasherized section id' do
    assert_equal '/contribute/guidelines#brand-abbreviation', guideline_path(:brand_abbreviation)
  end

  test 'an unknown section raises' do
    assert_raises(ArgumentError) { guideline_path(:does_not_exist) }
  end

  test 'guideline_link has an accessible name' do
    html = guideline_link(:price, 'Price')

    assert_includes html, 'href="/contribute/guidelines#price"'
    assert_includes html, 'aria-label="Guidelines: Price"'
  end

  test 'contact_email_link hides the address from the page source' do
    html = contact_email_link

    assert_predicate html, :html_safe?
    assert_not_includes html, 'info@hifilog.com'
    assert_equal 'info@hifilog.com', CGI.unescapeHTML(html[/>([^<]+)</, 1])
  end
end
