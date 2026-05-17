# frozen_string_literal: true

require 'test_helper'

class FormatHelperTest < ActionView::TestCase
  test 'format_iso_date' do
    assert_equal format_iso_date(Time.zone.local(2000, 1, 1)), '2000-01-01T00:00+0000'
  end

  test 'format_iso_datetime' do
    assert_equal format_iso_datetime(Time.zone.local(2000, 1, 1, 12, 30)), '2000-01-01T12:30+0000'
  end

  test 'strip_script_tags removes script elements' do
    html = '<p>Hello</p><script>alert(1)</script><b>World</b>'
    assert_equal '<p>Hello</p><b>World</b>', strip_script_tags(html)
  end

  test 'markdown_to_html strips script tags from rendered markdown' do
    html = markdown_to_html("Text\n\n<script>alert(1)</script>\n\n**bold**")
    assert_not_includes html, '<script>'
    assert_includes html, 'bold'
  end
end
