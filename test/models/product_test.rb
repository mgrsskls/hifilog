# frozen_string_literal: true

require 'test_helper'

class ProductTest < ActiveSupport::TestCase
  test 'release_date' do
    assert_equal '2020/06/01', products(:release_date_ymd).formatted_release_date
    assert_equal '2020/06', products(:release_date_ym).formatted_release_date
    assert_equal '2020', products(:release_date_yd).formatted_release_date
    assert_nil products(:release_date_md).formatted_release_date
    assert_equal '2020', products(:release_date_y).formatted_release_date
    assert_nil products(:release_date_m).formatted_release_date
    assert_nil products(:release_date_d).formatted_release_date
  end

  test 'display_name' do
    product = Product.new(name: 'product_name')

    assert_equal 'product_name', product.display_name
    assert_equal 'Feliks Audio Elise', products(:one).display_name
  end

  test 'url_slug' do
    assert_equal 'feliks-audio-elise', products(:one).url_slug
  end

  test 'validations' do
    product = Product.new
    assert_not product.valid?
    assert product.errors[:name].any?
    assert product.errors[:sub_categories].any?
  end

  test 'brand presence validation' do
    product = Product.new(name: 'Test Product')
    assert_not product.valid?
    assert product.errors[:brand].any?
  end

  test 'model_no uniqueness per brand' do
    product1 = Product.create!(
      name: 'name',
      model_no: 'model123',
      brand: brands(:one),
      sub_categories: [sub_categories(:one)]
    )
    product2 = Product.new(
      name: 'Different Name',
      model_no: product1.model_no,
      brand_id: product1.brand_id,
      sub_category_ids: product1.sub_category_ids
    )
    assert_not product2.valid?
    assert product2.errors[:model_no].any?
  end

  test 'model_no can be duplicate across brands' do
    product1 = products(:one)
    product2 = Product.new(
      name: 'Different Name',
      model_no: product1.model_no,
      brand_id: brands(:two).id,
      sub_category_ids: [sub_categories(:one).id]
    )
    assert product2.valid?
  end

  test 'price validation' do
    product = products(:one)
    product.price = 0
    assert_not product.valid?
    assert product.errors[:price].any?

    product.price = -100
    assert_not product.valid?

    product.price = 99.99
    product.price_currency = 'USD'
    assert product.valid?
  end

  test 'price currency required if price present' do
    product = Product.new(name: 'name', brand: brands(:one), sub_categories: [sub_categories(:one)], price: 100)
    assert_not product.valid?
    assert product.errors[:price_currency].any?
  end

  test 'release_day validation' do
    product = Product.new(name: 'name', brand: brands(:one), sub_categories: [sub_categories(:one)],
                          release_year: 1900, release_month: 1, release_day: 32)
    assert_not product.valid?
    assert product.errors[:release_day].any?

    product = Product.new(name: 'name', brand: brands(:one), sub_categories: [sub_categories(:one)],
                          release_year: 1900, release_month: 1, release_day: 0)
    assert_not product.valid?

    product = Product.new(name: 'name', brand: brands(:one), sub_categories: [sub_categories(:one)],
                          release_year: 1900, release_month: 1, release_day: 15)
    assert product.valid?
  end

  test 'release_month validation' do
    product = Product.new(name: 'name', brand: brands(:one), sub_categories: [sub_categories(:one)],
                          release_year: 1900, release_month: 13)
    assert_not product.valid?
    assert product.errors[:release_month].any?

    product = Product.new(name: 'name', brand: brands(:one), sub_categories: [sub_categories(:one)],
                          release_year: 1900, release_month: 6)
    assert product.valid?
  end

  test 'release_year validation' do
    product = Product.new(name: 'name', brand: brands(:one), sub_categories: [sub_categories(:one)], release_year: 1899)
    assert_not product.valid?
    assert product.errors[:release_year].any?

    product = Product.new(name: 'name', brand: brands(:one), sub_categories: [sub_categories(:one)], release_year: 1900)
    assert product.valid?
  end

  test 'discontinued_date' do
    product = products(:one)
    assert_nil product.discontinued_date

    product.update!(discontinued: true, discontinued_year: 2023, discontinued_month: 6, discontinued_day: 15)
    assert_equal Date.new(2023, 6, 15), product.discontinued_date
  end

  test 'sub_category_names' do
    product = products(:one)
    names = product.sub_category_names
    assert_equal product.sub_categories.map(&:name), names
  end

  test 'path method' do
    product = products(:one)
    assert_match product.friendly_id, product.path
  end

  test 'url method' do
    product = products(:one)
    assert_match product.friendly_id, product.url
  end
end
