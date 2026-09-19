# frozen_string_literal: true

require 'test_helper'

# Product name, title and slug with a product series. See docs/product-series.md, "Product name,
# title and slug".
class ProductSeriesNamingTest < ActiveSupport::TestCase
  setup do
    @brand = Brand.create!(name: "Fezz #{SecureRandom.hex(3)}", country_code: 'PL', discontinued: false)
    @evolution = ProductSeries.create!(brand: @brand, name: 'Evolution')
    @legacy = ProductSeries.create!(brand: @brand, name: 'Legacy')
  end

  def build_product(name: 'Omega Lupi', **attributes)
    Product.new(name:, brand: @brand, sub_categories: [sub_categories(:one)], **attributes)
  end

  test 'the series is part of the slug, not of the title' do
    product = build_product(product_series: @evolution)
    product.save!

    assert_equal "#{@brand.display_name} Omega Lupi", product.display_name
    assert_equal "#{@brand.display_name} Omega Lupi (Evolution series)", product.qualified_name
    assert_equal "#{@brand.display_name.parameterize}-evolution-omega-lupi", product.slug
  end

  test 'without a series the title and slug do not change' do
    product = build_product
    product.save!

    assert_equal product.display_name, product.qualified_name
    assert_equal "#{@brand.display_name.parameterize}-omega-lupi", product.slug
  end

  test 'two products with the same name in two series are valid and get readable slugs' do
    evolution = build_product(product_series: @evolution)
    evolution.save!
    legacy = build_product(product_series: @legacy)

    assert legacy.valid?, legacy.errors.full_messages.to_sentence
    legacy.save!
    assert_equal "#{@brand.display_name.parameterize}-legacy-omega-lupi", legacy.slug
  end

  test 'the same name in the same series is invalid' do
    build_product(product_series: @evolution).save!
    duplicate = build_product(name: 'omega lupi', product_series: @evolution)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name],
                    I18n.t('activerecord.errors.models.product.attributes.name.taken_in_series')
  end

  test 'the same name without a series is invalid' do
    build_product.save!
    duplicate = build_product

    assert_not duplicate.valid?
  end

  test 'an existing duplicate does not block an unrelated edit' do
    first = build_product
    first.save!
    second = build_product
    second.save!(validate: false)

    second.description = 'An edit that does not touch the name'

    assert second.valid?, second.errors.full_messages.to_sentence
  end

  test 'the name must not start or end with the series name' do
    ['Evolution Omega Lupi', 'Omega Lupi Evolution'].each do |name|
      product = build_product(name:, product_series: @evolution)

      assert_not product.valid?, name
      assert product.errors.added?(:name, :contains_series_name, series: 'Evolution'), name
    end
  end

  test 'a name that contains the series name inside a word is valid' do
    product = build_product(name: 'Evolutionary', product_series: @evolution)

    assert product.valid?, product.errors.full_messages.to_sentence
  end

  test 'a series of another brand is invalid' do
    product = build_product(product_series: product_series(:heritage))

    assert_not product.valid?
    assert product.errors.added?(:product_series, :other_brand)
  end

  test 'a change of the series changes the slug and keeps the old one' do
    product = build_product
    product.save!
    old_slug = product.slug

    product.update!(product_series: @evolution)

    assert_includes product.slug, 'evolution'
    assert_equal product, Product.friendly.find(old_slug)
  end

  test 'product_series_name selects an existing series, ignoring case' do
    product = build_product(product_series_name: 'evolution')
    product.save!

    assert_equal @evolution, product.product_series
  end

  test 'product_series_name creates a new series of the brand' do
    product = build_product(product_series_name: 'Reference')

    assert_difference 'ProductSeries.count', 1 do
      product.save!
    end

    assert_equal 'Reference', product.product_series.name
    assert_equal @brand, product.product_series.brand
    assert_includes product.slug, 'reference'
    assert_equal 1, product.product_series.reload.products_count
  end

  test 'an empty product_series_name removes the series' do
    product = build_product(product_series: @evolution)
    product.save!

    product.update!(product_series_name: '')

    assert_nil product.reload.product_series
  end

  test 'an invalid new series name shows its own error' do
    product = build_product(product_series_name: "#{@brand.name} Line")

    assert_not product.valid?
    assert product.errors[:product_series_name].any?
    assert_empty product.errors[:product_series]
  end

  test 'a brand change removes a series of the old brand' do
    product = build_product(product_series: @evolution)
    product.save!

    product.update!(brand: brands(:two))

    assert_nil product.reload.product_series
  end

  test 'moving the series name out of the product name keeps the slug' do
    product = build_product(name: 'Evolution Omega Lupi')
    product.save!
    old_slug = product.slug

    product.update!(name: 'Omega Lupi', product_series: @evolution)

    assert_equal old_slug, product.slug
  end

  test 'a variant title uses the product title and the series of the product' do
    product = build_product(product_series: @evolution)
    product.save!
    variant = ProductVariant.create!(product:, name: 'Black', discontinued: false)

    assert_equal "#{@brand.display_name} Omega Lupi Black", variant.display_name
    assert_equal "#{@brand.display_name} Omega Lupi Black (Evolution series)", variant.qualified_name
  end

  test 'product_items carries the series of the product on variant rows' do
    product = build_product(product_series: @evolution)
    product.save!
    variant = ProductVariant.create!(product:, name: 'Black', discontinued: false)

    row = ProductItem.find_by(item_type: 'ProductVariant', product_variant_id: variant.id)

    assert_equal @evolution.id, row.product_series_id
    assert_equal 'Evolution', row.series_name
  end
end
