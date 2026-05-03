# frozen_string_literal: true

require 'test_helper'

require 'securerandom'

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

  test 'url slug appends model number when present' do
    product = products(:one)
    product.update!(model_no: 'MK-II')

    assert_includes product.url_slug, 'mk-ii'
  end

  test 'meta description falls back to category copy when description missing' do
    product = products(:without_custom_attributes)
    product.update!(description: nil, name: 'Descriptor Product')

    copy = product.meta_desc
    assert_includes copy, 'Descriptor Product'
    assert_includes copy, product.brand.name
    assert_includes copy, product.sub_categories.map(&:name).join(' / ')
  end

  test 'meta description truncates rich description text' do
    product = products(:without_custom_attributes)
    long = "<p>#{'word ' * 80}</p>"
    product.update!(description: long)

    assert_operator product.meta_desc.length, :<=, 220
  end

  test 'custom attributes list translates stored option ids' do
    product = products(:one)
    option = custom_attributes(:one)
    product.update!(custom_attributes: { option.id.to_s => '1' })

    assert_includes product.custom_attributes_list, I18n.t('custom_attributes.stereo')
  end

  test 'custom attributes resources indexes definitions by label' do
    product = products(:with_custom_attributes)

    lookup = product.custom_attributes_resources
    assert_kind_of Hash, lookup
    assert_predicate lookup['boolean'], :present?
  end

  test 'invalidate cache callback clears aggregated counters' do
    Rails.cache.write('/products_count', 123)
    Rails.cache.write('/newest_products', [1])

    products(:one).send(:invalidate_cache)

    assert_nil Rails.cache.read('/products_count')
    assert_nil Rails.cache.read('/newest_products')
  end

  test 'persisting merges new sub categories onto the associated brand' do
    created = nil
    standalone = brand = nil
    token = SecureRandom.hex(4)
    standalone = SubCategory.create!(name: "Isolated #{token}", category: categories(:one))
    brand = Brand.create!(name: "Side #{token}", country_code: 'US', discontinued: false)
    brand.sub_categories << sub_categories(:one)

    catalog_name = "Catalog #{token}"

    created = Product.create!(
      name: catalog_name,
      brand:,
      sub_category_ids: [standalone.id]
    )

    assert_includes brand.reload.sub_categories, standalone
  ensure
    Product.find_by(id: created&.id)&.destroy
    standalone&.destroy
    brand&.destroy
  end
end
