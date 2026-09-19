# frozen_string_literal: true

require 'test_helper'

# Every test uses its own sub categories and brands. Thus, the fixture catalogue cannot add
# candidates.
class SimilarBrands::QueryTest < ActiveSupport::TestCase
  setup do
    @token = SecureRandom.hex(4)
    @turntables = sub_category('Turntables')
    @amps = sub_category('Amps')
  end

  def sub_category(name)
    SubCategory.create!(name: "#{name} #{@token}", category: categories(:one))
  end

  # products: one hash for each product, for example { sub_categories: [@amps], price: 100 }
  def brand(name, products:, **attributes)
    brand = Brand.create!(name: "#{name} #{@token}", discontinued: false, **attributes)
    products.each_with_index do |product, index|
      Product.create!(name: "#{name} #{index} #{@token}", brand:, **product)
    end
    brand.recalculate_products_count!
    brand
  end

  def query(source, limit: 10, offset: 0)
    SimilarBrands::Query.new(brand: source, limit:, offset:).call
  end

  def ranked(source, **)
    query(source, **).ids
  end

  def turntable(**attributes) = { sub_categories: [@turntables], **attributes }
  def amp(**attributes) = { sub_categories: [@amps], **attributes }

  test 'excludes the brand itself and brands without a shared sub category' do
    source = brand('Source', products: [turntable])
    brand('Other', products: [amp])
    candidate = brand('Candidate', products: [turntable])

    assert_equal [candidate.id], ranked(source)
  end

  test 'a brand without products has no similar brands' do
    source = brand('Source', products: [])
    brand('Candidate', products: [turntable])

    assert_equal SimilarBrands::Query::EMPTY, query(source)
  end

  test 'a specialist ranks above a generalist' do
    source = brand('Source', products: [turntable, turntable, turntable])
    generalist = brand('Generalist', products: [turntable, amp, amp, amp])
    specialist = brand('Specialist', products: [turntable, turntable])

    assert_equal [specialist.id, generalist.id], ranked(source)
  end

  test 'the same country ranks higher' do
    source = brand('Source', products: [turntable], country_code: 'JP')
    other = brand('Other', products: [turntable], country_code: 'DE')
    same = brand('Same', products: [turntable], country_code: 'JP')

    assert_equal [same.id, other.id], ranked(source)
  end

  test 'an overlapping active period ranks higher' do
    source = brand('Source', products: [turntable], founded_year: 1970, discontinued: true, discontinued_year: 1990)
    later = brand('Later', products: [turntable], founded_year: 2005)
    contemporary = brand('Contemporary', products: [turntable], founded_year: 1968, discontinued: true,
                                         discontinued_year: 1985)

    assert_equal [contemporary.id, later.id], ranked(source).first(2)
  end

  test 'a larger share of the dominant attribute value ranks higher' do
    tube = { 'amplifier_type' => '2' }
    solid_state = { 'amplifier_type' => '1' }
    source = brand('Source', products: [amp(custom_attributes: tube), amp(custom_attributes: tube),
                                        amp(custom_attributes: solid_state)])
    none = brand('None', products: [amp(custom_attributes: solid_state), amp(custom_attributes: solid_state)])
    half = brand('Half', products: [amp(custom_attributes: tube), amp(custom_attributes: solid_state)])
    all = brand('All', products: [amp(custom_attributes: tube), amp(custom_attributes: tube)])

    assert_equal [all.id, half.id, none.id], ranked(source)
  end

  test 'a median price in the same band ranks higher' do
    source = brand('Source', products: [turntable(price: 1000, price_currency: 'EUR'),
                                        turntable(price: 2000, price_currency: 'EUR')])
    cheap = brand('Cheap', products: [turntable(price: 50, price_currency: 'EUR')])
    same = brand('Same', products: [turntable(price: 1400, price_currency: 'EUR')])

    assert_equal [same.id, cheap.id], ranked(source)
  end

  test 'the same status and then more products break a tie' do
    source = brand('Source', products: [turntable], discontinued: true)
    current = brand('Current', products: [turntable])
    small = brand('Small', products: [turntable], discontinued: true)
    large = brand('Large', products: [turntable, turntable, turntable], discontinued: true)

    assert_equal [large.id, small.id, current.id], ranked(source)
  end

  test 'offset returns the next page and the total counts all candidates' do
    source = brand('Source', products: [turntable])
    candidates = Array.new(3) { |index| brand("Candidate #{index}", products: [turntable]) }

    result = query(source, limit: 1, offset: 1)

    assert_equal [candidates[1].id], result.ids
    assert_equal 3, result.total_count
  end

  test 'a candidate below the minimum score is not shown' do
    source = brand('Source', products: [turntable])
    # 1 of 16 products is a turntable: 100 / 16 = 6.25 points, less than MIN_SCORE.
    brand('Weak', products: [turntable] + Array.new(15) { amp })

    assert_empty ranked(source)
  end
end
