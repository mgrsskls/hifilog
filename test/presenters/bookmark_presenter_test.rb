# frozen_string_literal: true

require 'test_helper'

class BookmarkPresenterTest < ActiveSupport::TestCase
  setup do
    @product_variant_bookmark = BookmarkPresenter.new(bookmarks(:with_product_variant))
    @product_bookmark = BookmarkPresenter.new(bookmarks(:with_product))
    @event_bookmark = BookmarkPresenter.new(bookmarks(:with_event))
    @brand_bookmark = BookmarkPresenter.new(bookmarks(:with_brand))
    @discontinued_brand_bookmark = BookmarkPresenter.new(bookmarks(:with_discontinued_brand))
  end

  test 'delegates modelling metadata for products and variants' do
    assert_equal @product_bookmark.product, products(:one)
    assert_not_predicate @product_bookmark.product_variant, :present?

    assert_equal @product_variant_bookmark.product_variant, product_variants(:one)

    assert_not_predicate @product_variant_bookmark.type, :blank?
    assert_not_predicate @product_bookmark.display_name, :blank?
  end

  test 'routing helpers produce dashboard removal targets consistent with bookmarks' do
    assert_match(%r{/bookmarks/}, @product_bookmark.delete_path)
    assert_predicate @product_bookmark.delete_confirm_msg, :present?
    assert_predicate @product_variant_bookmark.delete_button_label, :present?
  end

  test 'event bookmark exposes metadata and discontinued when event ended' do
    presenter = BookmarkPresenter.new(bookmarks(:with_past_event))

    assert_predicate presenter.event, :present?
    assert_equal Event.model_name.human(count: 1), presenter.type
    assert_equal presenter.event.name, presenter.display_name

    travel_to Time.zone.local(2026, 6, 1, 12, 0, 0) do
      assert presenter.discontinued?
    end
  end

  test 'event bookmark is not discontinued for future events' do
    travel_to Time.zone.local(2026, 6, 1, 12, 0, 0) do
      assert_not @event_bookmark.discontinued?
    end
  end

  test 'brand bookmark type display name and discontinued' do
    assert_equal Brand.model_name.human(count: 1), @brand_bookmark.type
    assert_equal brands(:three).name, @discontinued_brand_bookmark.display_name
    assert @discontinued_brand_bookmark.discontinued?
    assert_not @brand_bookmark.discontinued?
  end

  test 'delegates association attributes to bookmark' do
    assert_equal bookmarks(:with_product).id, @product_bookmark.id
  end
end
