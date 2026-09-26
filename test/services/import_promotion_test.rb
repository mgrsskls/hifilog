# frozen_string_literal: true

require 'test_helper'

# The only path from an import to the catalogue, so this is where the promise
# that nothing reaches the catalogue unreviewed is checked.
class ImportPromotionTest < ActiveSupport::TestCase
  # Minitest 6 no longer ships `stub`, and one test does not justify a gem.
  # The class method is replaced for the length of the block and put back
  # afterwards, whatever happens inside it.
  def with_failing(klass, name)
    original = klass.method(name)
    klass.define_singleton_method(name) do |*|
      raise ActiveRecord::RecordInvalid, ProductVariant.new
    end
    yield
  ensure
    klass.define_singleton_method(name, original)
  end

  def candidate(**overrides)
    ImportCandidate.create!(
      {
        brand: brands(:one),
        brand_slug: brands(:one).slug,
        name: 'Euforia Mk2',
        source_url: "https://feliksaudio.pl/products/#{SecureRandom.hex(4)}",
        sub_category_ids: [sub_categories(:one).id],
        status: 'approved',
        provenance: { 'name' => { 'source' => 'jsonld', 'confidence' => 0.95 } }
      }.merge(overrides)
    )
  end

  test 'an approved candidate becomes a product' do
    record = candidate(model_no: 'EUF2', description: 'A headphone amplifier.')

    assert_difference 'Product.count', 1 do
      result = ImportPromotion.call(record)

      assert_predicate result, :success?
    end

    product = record.reload.product

    assert_equal 'Euforia Mk2', product.name
    assert_equal brands(:one), product.brand
    assert_equal [sub_categories(:one)], product.sub_categories.to_a
    assert_predicate product.slug, :present?
    assert_predicate record, :imported?
  end

  # A candidate holds whatever the extractor wrote, and the extractor writes the first unit of a
  # definition for every figure it reads. A candidate from before a definition changed therefore
  # carries a unit that definition no longer offers. Promotion copies the specs verbatim and never
  # sees the product form, so the cleaning has to sit on the model -- see
  # CustomAttribute.prune_unsupported_keys. Without it the new product holds a unit no filter can
  # reach.
  test 'a unit the definition no longer offers does not reach the product' do
    custom_attributes(:four).update!(units: %w[db], qualifiers: %w[drive_1w_1m])
    record = candidate(custom_attributes: { 'weight' => { 'value' => 88, 'unit' => 'db_1w_1m' } })

    assert_predicate ImportPromotion.call(record), :success?

    entry = record.reload.product.custom_attributes['weight']

    assert_equal 88, entry['value']
    assert_not entry.key?('unit')
  end

  test 'a condition the definition offers survives promotion' do
    custom_attributes(:four).update!(units: %w[db], qualifiers: %w[drive_1w_1m])
    record = candidate(
      custom_attributes: { 'weight' => { 'value' => 88, 'unit' => 'db', 'qualifier' => 'drive_1w_1m' } }
    )

    assert_predicate ImportPromotion.call(record), :success?

    entry = record.reload.product.custom_attributes['weight']

    assert_equal 'db', entry['unit']
    assert_equal 'drive_1w_1m', entry['qualifier']
  end

  test 'every sub category of the candidate reaches the product' do
    # A product can be two things at once, and both must arrive.
    record = candidate(sub_category_ids: [sub_categories(:one).id, sub_categories(:two).id])
    ImportPromotion.call(record)

    assert_equal 2, record.reload.product.sub_categories.count
  end

  test "the shop's version words become a variant" do
    record = candidate(variant_name: 'Walnut')

    assert_difference 'ProductVariant.count', 1 do
      ImportPromotion.call(record)
    end

    variant = record.reload.product.product_variants.first

    assert_equal 'Walnut', variant.name
  end

  test 'a candidate with no sub category is refused, not written' do
    record = candidate(sub_category_ids: [])

    assert_no_difference 'Product.count' do
      result = ImportPromotion.call(record)

      assert_not_predicate result, :success?
      assert_equal 'no sub category', result.error
    end
    # It stays approved, so a later run can write it once the category is set.
    assert_predicate record.reload, :approved?
  end

  test 'a candidate whose brand is not in the catalogue is refused' do
    record = candidate(brand: nil, brand_slug: 'brand-that-does-not-exist')

    assert_no_difference 'Product.count' do
      result = ImportPromotion.call(record)

      assert_not_predicate result, :success?
    end
  end

  test 'a price without a currency is dropped, and the product is still written' do
    # The model refuses a price with no currency. Everything else the page
    # stated is still worth having, so the price goes and the product stays.
    record = candidate(price: 1999, price_currency: nil)

    assert_difference 'Product.count', 1 do
      assert_predicate ImportPromotion.call(record), :success?
    end
    assert_nil record.reload.product.price
  end

  test 'a price with its currency is kept' do
    record = candidate(price: 1999, price_currency: 'EUR')
    ImportPromotion.call(record)
    product = record.reload.product

    assert_equal 1999, product.price
    assert_equal 'EUR', product.price_currency
  end

  test 'a model number that the brand already uses is refused rather than duplicated' do
    # The product is made here rather than taken from the fixtures, which carry
    # no model number: a test that skips itself checks nothing.
    existing = Product.create!(
      brand: brands(:one), name: 'Euforia', model_no: 'EUF1',
      sub_categories: [sub_categories(:one)]
    )
    record = candidate(brand: existing.brand, model_no: existing.model_no)

    assert_no_difference 'Product.count' do
      result = ImportPromotion.call(record)

      assert_not_predicate result, :success?
      assert_match(/model no/i, result.error)
    end
  end

  test 'nothing is left half written when the variant cannot be saved' do
    # The variant is made to fail rather than fed bad data: ProductVariant
    # accepts almost any name, so there is no value that makes it invalid, and
    # a test that cannot make the second write fail does not test the
    # transaction at all.
    record = candidate(variant_name: 'Walnut')

    assert_no_difference ['Product.count', 'ProductVariant.count'] do
      with_failing(ProductVariant, :create!) do
        result = ImportPromotion.call(record)

        assert_not_predicate result, :success?
      end
    end
    assert_predicate record.reload, :approved?
  end

  test 'a candidate that was already imported is not written a second time' do
    record = candidate
    ImportPromotion.call(record)

    assert_no_difference 'Product.count' do
      result = ImportPromotion.call(record.reload)

      assert_not_predicate result, :success?
      assert_equal 'already imported', result.error
    end
  end

  test 'run_all takes the approved candidates and leaves the others alone' do
    approved = candidate
    pending_one = candidate(status: 'pending')

    results = ImportPromotion.run_all

    assert_includes results.map(&:candidate), approved
    assert_not_includes results.map(&:candidate), pending_one
  end
end
