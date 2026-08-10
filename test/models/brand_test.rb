# frozen_string_literal: true

require 'base64'
require 'test_helper'

class BrandTest < ActiveSupport::TestCase
  MINIMAL_PNG_BYTES = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ).freeze

  test 'validations' do
    brand = Brand.new
    assert_not brand.valid?
    assert brand.errors[:name].any?
  end

  test 'name uniqueness' do
    brand1 = brands(:one)
    brand2 = Brand.new(name: brand1.name)
    assert_not brand2.valid?
    assert brand2.errors[:name].any?
  end

  test 'country_code_has_allowed_value validation' do
    brand = Brand.new(name: 'Test Brand', country_code: 'INVALID')
    assert_not brand.valid?
    assert brand.errors[:country_code].any?

    brand.country_code = 'DE'
    assert brand.valid?
  end

  test 'founded_year validation' do
    brand = Brand.new(name: 'name', founded_year: 'not_a_number')
    assert_not brand.valid?
    assert brand.errors[:founded_year].any?

    brand = Brand.new(name: 'name', founded_year: 1920)
    assert brand.valid?
  end

  test 'country_name' do
    brand = brands(:one)
    brand.update!(country_code: 'DE')
    assert_equal 'Germany', brand.country_name
  end

  test 'founded_date' do
    brand = Brand.new(name: 'brand')
    assert_nil brand.founded_date

    brand.update!(founded_year: 2020, founded_month: 6, founded_day: 15)
    assert_equal Date.new(2020, 6, 15), brand.founded_date
  end

  test 'discontinued_date' do
    brand = Brand.new(name: 'brand')
    assert_nil brand.discontinued_date

    brand.update!(discontinued: true, discontinued_year: 2023, discontinued_month: 6, discontinued_day: 15)
    assert_equal Date.new(2023, 6, 15), brand.discontinued_date
  end

  test 'display_name' do
    brand = brands(:one)
    assert_equal brand.name, brand.display_name

    brand = brands(:with_abbreviation)
    assert_equal brand.abbreviation, brand.display_name
  end

  # The column only earns its keep for short forms search cannot reach through `name`.
  # Anything already inside the name is cleared, which is what lets every display site
  # render it without checking whether it would be a repetition.
  test 'abbreviation is kept when it is not part of the name' do
    brand = Brand.new(name: 'Bang & Olufsen', abbreviation: 'B&O')

    assert_predicate brand, :valid?
    assert_equal 'B&O', brand.abbreviation
  end

  test 'abbreviation identical to the name is cleared' do
    brand = Brand.new(name: 'Fezz Audio', abbreviation: 'fezz audio')

    assert_predicate brand, :valid?
    assert_nil brand.abbreviation
  end

  test 'abbreviation that is a word of the name is cleared' do
    brand = Brand.new(name: 'Fezz Audio', abbreviation: 'Fezz')

    assert_predicate brand, :valid?
    assert_nil brand.abbreviation, 'searching "Fezz" already finds "Fezz Audio" via name'
  end

  test 'abbreviation ignores punctuation when deciding redundancy' do
    # "DeVORE" is a word of the name once punctuation and case are normalised the way
    # search normalises them, so it adds nothing.
    contained = Brand.new(name: 'DeVORE Fidelity', abbreviation: 'de-vore')
    assert_predicate contained, :valid?
    assert_nil contained.abbreviation

    # "AAW" survives the same normalisation as a token of its own.
    distinct = Brand.new(name: 'Advanced Acoustic Werkes', abbreviation: 'AAW')
    assert_predicate distinct, :valid?
    assert_equal 'AAW', distinct.abbreviation
  end

  # Product slugs embed the brand name, and nothing on Product notices a brand rename --
  # see Product.resync_slugs_for.
  test 'renaming a brand re-slugs its products' do
    brand = brands(:one)
    product = brand.products.first
    previous_product_slug = product.slug

    brand.update!(name: 'Renamed Audio')

    assert_equal 'renamed-audio', brand.reload.slug
    assert_equal product.normalize_friendly_id("Renamed Audio #{product.name}"),
                 product.reload.slug
    assert_not_equal previous_product_slug, product.slug
  end

  test 'a renamed brand leaves its products old slugs resolvable' do
    brand = brands(:one)
    product = brand.products.first
    previous_product_slug = product.slug

    brand.update!(name: 'Renamed Audio')

    assert_equal product, Product.friendly.find(previous_product_slug)
  end

  test 'adding an abbreviation re-slugs the products' do
    brand = brands(:one)
    product = brand.products.first
    previous_product_slug = product.slug

    brand.update!(abbreviation: 'FA')

    assert_equal product.normalize_friendly_id("FA #{product.name}"), product.reload.slug
    assert_not_equal previous_product_slug, product.slug
    assert_equal product, Product.friendly.find(previous_product_slug)
  end

  test 'removing an abbreviation re-slugs the products back to the brand name' do
    brand = brands(:one)
    brand.update!(abbreviation: 'FA')
    product = brand.products.first

    brand.update!(abbreviation: nil)

    assert_equal product.normalize_friendly_id("#{brand.name} #{product.name}"),
                 product.reload.slug
  end

  # The abbreviation is cleared by clear_abbreviation_when_contained_in_name here, so it
  # never reaches the database -- and product slugs must not move on the strength of a value
  # that was discarded.
  test 'an abbreviation rejected as redundant leaves product slugs alone' do
    brand = brands(:one)
    slugs = brand.products.pluck(:slug)

    brand.update!(abbreviation: brand.name.split.first)

    assert_nil brand.reload.abbreviation
    assert_equal slugs, brand.products.reload.pluck(:slug)
  end

  test 'editing a brand without touching its name or abbreviation leaves product slugs alone' do
    brand = brands(:one)
    slugs = brand.products.pluck(:slug)

    brand.update!(country_code: 'PL')

    assert_equal slugs, brand.products.reload.pluck(:slug)
  end

  test 'url' do
    brand = brands(:one)
    assert_match brand.friendly_id, brand.url
  end

  test 'categories' do
    brand = brands(:one)
    categories = brand.categories
    assert categories.is_a?(Array)
    assert(categories.all?(Category))
  end

  test 'formatted_description without description' do
    brand = Brand.new(name: 'Test', country_code: 'DE', founded_year: 2020)
    desc = brand.formatted_description
    assert_not_nil desc
    assert_includes desc, 'Germany'
    assert_includes desc, 'Test'
  end

  test 'formatted_description with all attributes' do
    brand = Brand.new(
      name: 'Test Brand',
      country_code: 'US',
      founded_year: 2000,
      discontinued_year: 2020,
      discontinued: true
    )
    desc = brand.formatted_description
    assert_not_nil desc
    assert_includes desc, 'was'
    assert_includes desc, 'founded in 2000'
    assert_includes desc, 'discontinued in 2020'
  end

  test 'formatted_description with custom description' do
    brand = Brand.new(name: 'Test', description: '**Bold text**')
    desc = brand.formatted_description
    assert_includes desc, '<strong>Bold text</strong>'
  end

  test 'meta_desc uses the written description and strips its markup' do
    brand = Brand.new(name: 'Test', description: '**Bold text**')

    assert_equal 'Bold text', brand.meta_desc
  end

  test 'meta_desc truncates a long written description' do
    brand = Brand.new(name: 'Test', description: 'word ' * 80)

    assert_operator brand.meta_desc.length, :<=, 200
  end

  test 'meta_desc appends the catalog sentence to the generated summary' do
    brand = Brand.new(name: 'Test', country_code: 'DE', founded_year: 2020)
    copy = brand.meta_desc

    assert_includes copy, 'Germany'
    assert_includes copy, 'documented on HiFi Log'
    assert_not_includes copy, '<'
  end

  test 'meta_desc counts the catalogued products' do
    brand = brands(:one)
    brand.update!(description: nil)

    assert_includes brand.meta_desc, "#{brand.products.count} products are documented on HiFi Log."
  end

  test 'meta_desc counts products when the counter cache was never backfilled' do
    brand = brands(:one)
    brand.update!(description: nil)
    brand.products_count = nil

    assert_includes brand.meta_desc, "#{brand.products.count} products are documented on HiFi Log."
  end

  test 'recalculate_products_count! counts products and variants' do
    brand = brands(:one)
    expected = brand.products.count +
               ProductVariant.joins(:product).where(products: { brand_id: brand.id }).count
    brand.update!(products_count: -1)

    brand.recalculate_products_count!

    assert_equal expected, brand.reload.products_count
  end

  test 'meta_desc falls back to a plain sentence when nothing is known' do
    brand = Brand.new(name: 'Nondescript')

    assert_equal 'Nondescript is an audio hi-fi brand. Its products, specifications and history ' \
                 'are documented on HiFi Log.', brand.meta_desc
  end

  test 'meta_desc uses the past tense for a discontinued brand with nothing known' do
    brand = Brand.new(name: 'Nondescript', discontinued: true)

    assert_includes brand.meta_desc, 'was an audio hi-fi brand.'
  end

  test 'meta_desc is a single squished line' do
    brand = brands(:one)
    brand.update!(description: nil)

    copy = brand.meta_desc
    assert_not_includes copy, "\n"
    assert_not_includes copy, '  '
  end

  test 'rejects logo with disallowed content type' do
    brand = brands(:one)
    brand.logo.attach(
      io: StringIO.new('%PDF-1.4'),
      filename: 'logo.pdf',
      content_type: 'application/pdf'
    )
    assert_not brand.valid?
    assert brand.errors.of_kind?(:logo, :invalid_content_type)
  end

  test 'rejects logo larger than 5 MB' do
    brand = brands(:one)
    brand.logo.attach(
      io: StringIO.new('x'),
      filename: 'logo.jpg',
      content_type: 'image/jpeg'
    )
    brand.logo.blob.define_singleton_method(:byte_size) { 5_000_001 }

    assert_not brand.valid?
    assert brand.errors.of_kind?(:logo, :too_large)
  end

  test 'purges logo when remove_logo flag is set' do
    brand = brands(:one)
    brand.logo.attach(
      io: StringIO.new(MINIMAL_PNG_BYTES),
      filename: 'logo.png',
      content_type: 'image/png'
    )
    brand.save!

    brand.remove_logo = '1'
    assert brand.save
    brand.reload

    assert_not_predicate brand.logo, :attached?
  end

  test 'replace upload wins when remove_logo checked and new logo uploaded together' do
    brand = brands(:one)
    brand.logo.attach(
      io: StringIO.new(MINIMAL_PNG_BYTES),
      filename: 'logo.png',
      content_type: 'image/png'
    )
    brand.save!

    brand.remove_logo = '1'
    brand.logo.attach(
      io: StringIO.new(MINIMAL_PNG_BYTES),
      filename: 'replaced.png',
      content_type: 'image/png'
    )
    assert brand.save
    brand.reload

    assert_predicate brand.logo, :attached?
  end
end
