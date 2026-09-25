# frozen_string_literal: true

require 'test_helper'

class ProductSeriesTest < ActiveSupport::TestCase
  def create_product(name:, series: nil, brand: brands(:one), **attributes)
    Product.create!(name: "#{name} #{SecureRandom.hex(3)}", brand:, product_series: series,
                    sub_categories: [sub_categories(:one)], **attributes)
  end

  test 'label adds "series" to the name' do
    assert_equal 'Evolution series', product_series(:evolution).label
  end

  test 'label does not repeat "series" when the name ends with it' do
    series = ProductSeries.new(name: '800 Series', brand: brands(:one))

    assert_equal '800 Series', series.label
  end

  test 'display_name and display_label start with the brand' do
    series = product_series(:evolution)

    assert_equal "#{brands(:one).display_name} Evolution", series.display_name
    assert_equal "#{brands(:one).display_name} Evolution series", series.display_label
  end

  test 'name must not start with the brand name' do
    series = ProductSeries.new(brand: brands(:one), name: "#{brands(:one).name} Reference")

    assert_not series.valid?
    assert series.errors.added?(:name, :starts_with_brand_name, brand: brands(:one).display_name)
  end

  test 'a name that only begins with the letters of the brand is valid' do
    series = ProductSeries.new(brand: brands(:two), name: 'ZMFX')

    assert series.valid?, series.errors.full_messages.to_sentence
  end

  test 'name is unique per brand, ignoring case' do
    duplicate = ProductSeries.new(brand: brands(:one), name: 'evolution')

    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
  end

  test 'the same name is valid for two brands' do
    series = ProductSeries.new(brand: brands(:two), name: 'Evolution')

    assert series.valid?, series.errors.full_messages.to_sentence
  end

  test 'slug is scoped to the brand' do
    series = ProductSeries.create!(brand: brands(:two), name: 'Evolution')

    assert_equal 'evolution', series.slug
  end

  test 'stats are derived from the products' do
    series = ProductSeries.create!(brand: brands(:one), name: "Stats #{SecureRandom.hex(3)}")
    create_product(name: 'Old', series:, release_year: 1990, discontinued: true, discontinued_year: 1995)
    create_product(name: 'New', series:, release_year: 2001, discontinued: true, discontinued_year: 2004)

    stats = series.reload.stats

    assert_equal 2, stats.products_count
    assert_equal 1990, stats.start_year
    assert_equal 2004, stats.end_year
    assert stats.discontinued?
    assert_equal '1990 – 2004', stats.years_label
  end

  test 'a series with a product in production ends in the present' do
    series = ProductSeries.create!(brand: brands(:one), name: "Present #{SecureRandom.hex(3)}")
    create_product(name: 'Current', series:, release_year: 2015, discontinued: false)

    assert_equal "2015 – #{I18n.t('product_series.present')}", series.stats.years_label
    assert_not series.stats.discontinued?
  end

  test 'the counter cache follows assignments' do
    series = ProductSeries.create!(brand: brands(:one), name: "Counted #{SecureRandom.hex(3)}")
    product = create_product(name: 'Counted', series:)

    assert_equal 1, series.reload.products_count

    product.update!(product_series: nil)

    assert_equal 0, series.reload.products_count
  end

  test 'a rename changes the slugs of its products and keeps the old ones' do
    series = ProductSeries.create!(brand: brands(:one), name: "Before #{SecureRandom.hex(3)}")
    product = create_product(name: 'Renamed', series:)
    old_slug = product.slug

    series.update!(name: "After #{SecureRandom.hex(3)}")

    product.reload
    assert_not_equal old_slug, product.slug
    assert_includes product.slug, series.name.parameterize
    assert_equal product, Product.friendly.find(old_slug)
  end

  test 'a delete removes the series from its products and changes their slugs' do
    series = ProductSeries.create!(brand: brands(:one), name: "Deleted #{SecureRandom.hex(3)}")
    product = create_product(name: 'Orphan', series:)
    old_slug = product.slug

    series.destroy!

    product.reload
    assert_nil product.product_series_id
    assert_not_includes product.slug, series.name.parameterize
    assert_equal product, Product.friendly.find(old_slug)
  end

  test 'a delete saves each product, so that the product and the series changelog show the removal' do
    series = ProductSeries.create!(brand: brands(:one), name: "Removed #{SecureRandom.hex(3)}")
    product = create_product(name: 'Versioned', series:)

    series.destroy!

    version = product.versions.last
    assert_equal [series.id, nil], version.changeset['product_series_id']
    assert_equal [series.id], version.product_series_ids
  end

  test 'changelog_versions has the versions of the series and of its added and removed products' do
    series = ProductSeries.create!(brand: brands(:one), name: "Changelog #{SecureRandom.hex(3)}")
    added = create_product(name: 'Added', series:)
    moved = create_product(name: 'Moved', series:)
    moved.update!(product_series: nil)
    edited = create_product(name: 'Edited', series:)
    edited.update!(description: 'Not a series change')
    other = create_product(name: 'Other', series: product_series(:legacy))

    versions = series.changelog_versions.to_a
    count = ->(product) { versions.count { |version| version.item == product } }

    assert_equal series.versions.first, versions.first
    assert_equal 1, count.call(added)
    assert_equal 2, count.call(moved)
    assert_equal 1, count.call(edited)
    assert_equal 0, count.call(other)
  end

  test 'a save after a rolled back delete does not record the series' do
    series = ProductSeries.create!(brand: brands(:one), name: "Rolled back #{SecureRandom.hex(3)}")
    product = create_product(name: 'Survivor', series:)

    ActiveRecord::Base.transaction do
      product.destroy!
      raise ActiveRecord::Rollback
    end
    product.update!(description: 'Saved after the rolled back delete')

    assert_nil product.versions.last.product_series_ids
    assert_equal 'update', product.versions.last.event
  end

  test 'a product save touches its brand and series without a version of them' do
    series = ProductSeries.create!(brand: brands(:one), name: "Touched #{SecureRandom.hex(3)}")
    product = create_product(name: 'Toucher', series:)

    assert_no_difference [-> { series.versions.count }, -> { series.brand.versions.count }] do
      product.update!(description: 'Touches the brand and the series')
    end
  end

  test 'sibling_products are in release order and do not include the product' do
    series = ProductSeries.create!(brand: brands(:one), name: "Siblings #{SecureRandom.hex(3)}")
    later = create_product(name: 'Later', series:, release_year: 2010)
    unknown = create_product(name: 'Unknown', series:)
    earlier = create_product(name: 'Earlier', series:, release_year: 2000)

    assert_equal [earlier, unknown], series.sibling_products(except: later).to_a
  end

  test 'deleting the brand deletes its series' do
    brand = Brand.create!(name: "Series Brand #{SecureRandom.hex(3)}")
    series = ProductSeries.create!(brand:, name: 'Line')

    brand.destroy!

    assert_not ProductSeries.exists?(series.id)
  end
end
