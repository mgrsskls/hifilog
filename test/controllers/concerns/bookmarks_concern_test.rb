# frozen_string_literal: true

require 'test_helper'

class BookmarksConcernTest < ActiveSupport::TestCase
  class Harness
    include Bookmarks
    include Rails.application.routes.url_helpers

    def default_url_options
      { host: 'www.example.com', protocol: 'https' }
    end
  end

  setup do
    @harness = Harness.new
  end

  test 'get_grouped_sub_categories nests presenters under sorted categories with dashboard bookmark paths' do
    presenters = [
      BookmarkPresenter.new(bookmarks(:with_product)),
      BookmarkPresenter.new(bookmarks(:with_product_variant))
    ]

    grouped = @harness.get_grouped_sub_categories(bookmarks: presenters)

    assert grouped.is_a?(Array)
    assert grouped.present?

    grouped.each do |category, subs|
      assert_instance_of Category, category
      subs.each do |row|
        assert row.key?(:friendly_id)
        assert_match %r{\A/dashboard/bookmarks}, row[:path]
      end
    end
  end
end
