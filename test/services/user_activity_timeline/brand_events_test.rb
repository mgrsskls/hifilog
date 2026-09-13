# frozen_string_literal: true

require 'test_helper'

class UserActivityTimeline::BrandEventsTest < ActiveSupport::TestCase
  setup do
    @user = users(:without_anything)
    # A brand with no catalog fixtures of its own, so pre-existing products/variants never leak
    # into these counts and lookups.
    @brand = Brand.create!(name: "Brand Events #{SecureRandom.hex(4)}", country_code: 'US', discontinued: false)
    @followed_at = Time.zone.local(2026, 5, 1, 12, 0, 0)
    @follow = travel_to(@followed_at) { BrandFollow.create!(user: @user, brand: @brand) }
  end

  test 'a product added after the follow appears in the dashboard feed' do
    product = create_product(at: @followed_at + 1.day, name: 'After Follow')

    items = feed_items

    assert_includes items.map(&:display_name), "#{@brand.display_name} #{product.name}"
    assert_includes items.map(&:verb), :brand_product_listed
  end

  test 'the brand is named on the row' do
    create_product(at: @followed_at + 1.day, name: 'Named Brand Row')

    item = feed_items.find { |i| i.verb == :brand_product_listed }

    assert_equal @brand.display_name, item.brand_name
    assert_equal @brand.id, item.brand_id
  end

  test 'a product added before the follow stays out of the feed' do
    product = create_product(at: @followed_at - 1.day, name: 'Before Follow')

    assert_not feed_lists?(product)
  end

  test 'a new variant appears as its own verb' do
    product = create_product(at: @followed_at + 1.day, name: 'With Variant')
    variant = travel_to(@followed_at + 2.days) do
      ProductVariant.create!(name: 'Silver', product:, discontinued: false)
    end

    item = feed_items.find { |i| i.verb == :brand_variant_listed }

    assert item
    assert_match variant.name, item.display_name
  end

  test 'entries from one brand on one day group into a single row' do
    day = @followed_at + 3.days
    3.times { |i| create_product(at: day + i.minutes, name: "Grouped #{i}") }

    rows = UserActivityTimeline.grouped_for_following(@user)
    grouped = rows.find { |r| r.is_a?(UserActivityTimeline::Grouped) && r.verb == :brand_product_listed }

    assert grouped
    assert_equal 3, grouped.items.size
  end

  test 'a deleted product leaves the feed' do
    product = create_product(at: @followed_at + 1.day, name: 'Deleted Again')

    assert feed_lists?(product)

    product.destroy

    assert_not feed_lists?(product)
  end

  test 'a re-branded product moves to the followers of its new brand' do
    product = travel_to(@followed_at + 1.day) do
      Product.create!(name: "Rebranded #{SecureRandom.hex(4)}", brand: brands(:one),
                      sub_category_ids: [sub_categories(:one).id])
    end

    assert_not feed_lists?(product)

    product.update!(brand: @brand)

    assert feed_lists?(product)
  end

  test 'brand events never reach a public profile feed' do
    create_product(at: @followed_at + 1.day, name: 'Profile Leak')

    rows = UserActivityTimeline.grouped_for(@user, public_profile_feed: true)
    verbs = rows.flat_map { |row| row.is_a?(UserActivityTimeline::Grouped) ? row.verb : row.item.verb }

    assert_not_includes verbs, :brand_product_listed
  end

  test 'another users brand follows do not leak into the viewers feed' do
    BrandFollow.create!(user: users(:visible), brand: brands(:one))
    product = create_product(at: @followed_at + 1.day, name: 'Other Users Brand', brand: brands(:one))

    assert_not feed_lists?(product)
  end

  test 'the paginated feed carries brand events too' do
    product = create_product(at: @followed_at + 1.day, name: 'Paginated Entry')

    page = UserActivityTimeline.paginated_for_following(@user, page: 1, per: 50)
    names = flat(page.rows).map(&:display_name)

    assert(names.any? { |name| name.include?(product.name) })
    assert_equal 1, page.activities.current_page
  end

  private

  def create_product(at:, name:, brand: @brand)
    travel_to(at) do
      Product.create!(
        name: "#{name} #{SecureRandom.hex(4)}",
        brand:,
        sub_category_ids: [sub_categories(:one).id]
      )
    end
  end

  def feed_items
    flat(UserActivityTimeline.grouped_for_following(@user))
  end

  # The row's title is the full catalog title, brand included, so a product is matched by name
  # rather than by the whole string.
  def feed_lists?(product)
    feed_items.any? { |item| item.display_name.include?(product.name) }
  end

  def flat(rows)
    rows.flat_map { |row| row.is_a?(UserActivityTimeline::Grouped) ? row.items : [row.item] }
  end
end
