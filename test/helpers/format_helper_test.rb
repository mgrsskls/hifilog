# frozen_string_literal: true

require 'test_helper'

class FormatHelperTest < ActionView::TestCase
  test 'format_iso_date' do
    assert_equal format_iso_date(Time.zone.local(2000, 1, 1)), '2000-01-01T00:00+0000'
  end

  test 'format_iso_datetime' do
    assert_equal format_iso_datetime(Time.zone.local(2000, 1, 1, 12, 30)), '2000-01-01T12:30+0000'
  end

  test 'markdown_to_html allows permitted tags' do
    html = markdown_to_html("Hello\n\n**bold**\n\n---\n\n[link](https://example.com)")
    assert_includes html, '<p>Hello</p>'
    assert_includes html, '<strong>bold</strong>'
    assert_includes html, '<hr>'
    assert_includes html, '<a href="https://example.com">link</a>'
  end

  test 'markdown_to_html allows headings, lists, and linked images' do
    html = markdown_to_html("# Heading\n\n- item\n\n[![alt](/img.png)](https://example.com)")
    assert_includes html, '<h1>'
    assert_includes html, '<ul>'
    assert_includes html, '<li>item</li>'
    assert_includes html, '<a href="https://example.com">'
    assert_includes html, '<img src="/img.png" alt="alt">'
  end

  test 'markdown_to_html escapes script tags' do
    html = markdown_to_html("Text\n\n<script>alert(1)</script>\n\n**bold**")
    assert_not_includes html, '<script>'
    assert_includes html, '&lt;script&gt;alert(1)&lt;/script&gt;'
    assert_includes html, '<strong>bold</strong>'
  end

  test 'markdown_to_html strips disallowed tags and attributes' do
    html = markdown_to_html("<iframe></iframe>\n\n<a href=\"https://example.com\" onclick=\"alert(1)\">link</a>")
    assert_not_includes html, '<iframe>'
    assert_includes html, '<a href="https://example.com">link</a>'
    assert_not_includes html, 'onclick'
  end
end
