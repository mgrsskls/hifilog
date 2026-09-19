# frozen_string_literal: true

require 'test_helper'

# Every test uses its own sub categories. Thus, the fixture catalogue cannot add candidates.
class SimilarProducts::QueryTest < ActiveSupport::TestCase
  setup do
    @token = SecureRandom.hex(4)
    @amps = sub_category('Amps')
    @phono = sub_category('Phono')
    @dacs = sub_category('DACs')
  end

  def sub_category(name)
    SubCategory.create!(name: "#{name} #{@token}", category: categories(:one))
  end

  def product(name, sub_categories:, **attributes)
    Product.create!(name: "#{name} #{@token}", brand: brands(:one), sub_categories:, **attributes)
  end

  # Product ids in rank order.
  def query(source, limit: 10, offset: 0)
    SimilarProducts::Query.new(product: source, sub_category_ids: source.sub_category_ids, limit:, offset:).call
  end

  def ranked(source, limit: 10, offset: 0)
    ids = query(source, limit:, offset:).ids
    product_ids = ProductItem.where(id: ids).pluck(:id, :product_id).to_h
    ids.map { |id| product_ids.fetch(id) }
  end

  test 'excludes the product itself and products without a shared sub category' do
    source = product('Source', sub_categories: [@amps])
    other = product('Other', sub_categories: [@dacs])
    candidate = product('Candidate', sub_categories: [@amps])

    assert_equal [candidate.id], ranked(source)
    assert_not_includes ranked(source), other.id
  end

  test 'an exact sub category match ranks above a partial match with more attribute points' do
    source = product('Source', sub_categories: [@amps],
                               custom_attributes: { 'amplifier_type' => '2' })
    partial = product('Partial', sub_categories: [@amps, @phono],
                                 custom_attributes: { 'amplifier_type' => '2' })
    exact = product('Exact', sub_categories: [@amps])

    assert_equal [exact.id, partial.id], ranked(source)
  end

  test 'a larger sub category overlap ranks higher when attributes are equal' do
    source = product('Source', sub_categories: [@amps, @phono])
    small = product('Small', sub_categories: [@amps, @dacs])
    large = product('Large', sub_categories: [@amps, @phono, @dacs])

    assert_equal [large.id, small.id], ranked(source)
  end

  test 'a matching option attribute ranks higher' do
    source = product('Source', sub_categories: [@amps], custom_attributes: { 'amplifier_type' => '2' })
    other = product('Other', sub_categories: [@amps], custom_attributes: { 'amplifier_type' => '1' })
    same = product('Same', sub_categories: [@amps], custom_attributes: { 'amplifier_type' => '2' })

    assert_equal [same.id, other.id], ranked(source)
  end

  test 'more shared values of an options attribute rank higher' do
    source = product('Source', sub_categories: [@amps],
                               custom_attributes: { 'input_connectors' => %w[1 2 3] })
    one = product('One', sub_categories: [@amps], custom_attributes: { 'input_connectors' => %w[1 9] })
    three = product('Three', sub_categories: [@amps], custom_attributes: { 'input_connectors' => %w[1 2 3] })

    assert_equal [three.id, one.id], ranked(source)
  end

  test 'a boolean attribute matches only the same value' do
    source = product('Source', sub_categories: [@amps], custom_attributes: { 'loudspeaker_bi_wiring' => true })
    other = product('Other', sub_categories: [@amps], custom_attributes: { 'loudspeaker_bi_wiring' => false })
    same = product('Same', sub_categories: [@amps], custom_attributes: { 'loudspeaker_bi_wiring' => true })

    assert_equal [same.id, other.id], ranked(source)
  end

  test 'a numeric value in the same class ranks higher' do
    power = ->(watts) { { 'amplifier_output_power' => { 'value' => { 'ohm_8' => watts }, 'unit' => 'w' } } }
    source = product('Source', sub_categories: [@amps], custom_attributes: power.call(50))
    high = product('High', sub_categories: [@amps], custom_attributes: power.call(250))
    medium = product('Medium', sub_categories: [@amps], custom_attributes: power.call(80))

    assert_equal [medium.id, high.id], ranked(source)
  end

  test 'a numeric value that is not a number does not break the query' do
    source = product('Source', sub_categories: [@amps],
                               custom_attributes: { 'nominal_impedance' => { 'value' => 8, 'unit' => 'ohm' } })
    broken = product('Broken', sub_categories: [@amps],
                               custom_attributes: { 'nominal_impedance' => { 'value' => 'n/a', 'unit' => 'ohm' } })

    assert_equal [broken.id], ranked(source)
  end

  test 'a price in the same band and currency ranks higher' do
    source = product('Source', sub_categories: [@amps], price: 1500, price_currency: 'EUR')
    other_currency = product('USD', sub_categories: [@amps], price: 1500, price_currency: 'USD')
    far = product('Far', sub_categories: [@amps], price: 50_000, price_currency: 'EUR')
    near = product('Near', sub_categories: [@amps], price: 700, price_currency: 'EUR')
    same = product('Same', sub_categories: [@amps], price: 2000, price_currency: 'EUR')

    result = ranked(source)

    assert_equal [same.id, near.id], result.first(2)
    assert_equal [other_currency.id, far.id].sort, result.last(2).sort
  end

  test 'the same discontinued status breaks a tie' do
    source = product('Source', sub_categories: [@amps], discontinued: true)
    current = product('Current', sub_categories: [@amps], discontinued: false)
    discontinued = product('Discontinued', sub_categories: [@amps], discontinued: true)

    assert_equal [discontinued.id, current.id], ranked(source)
  end

  test 'a closer release year breaks a tie, and a missing year comes last' do
    source = product('Source', sub_categories: [@amps], release_year: 1978)
    unknown = product('Unknown', sub_categories: [@amps])
    far = product('Far', sub_categories: [@amps], release_year: 2005)
    near = product('Near', sub_categories: [@amps], release_year: 1980)

    assert_equal [near.id, far.id, unknown.id], ranked(source)
  end

  test 'a candidate below the minimum score is not shown' do
    others = Array.new(10) { |index| sub_category("Extra #{index}") }
    source = product('Source', sub_categories: [@amps])
    product('Weak', sub_categories: [@amps, *others])

    # Overlap 1 / 11 * 100 = 9.1, which is less than MIN_SCORE.
    assert_empty ranked(source)
  end

  test 'the limit applies' do
    source = product('Source', sub_categories: [@amps])
    3.times { |index| product("Candidate #{index}", sub_categories: [@amps]) }

    assert_equal 2, ranked(source, limit: 2).size
  end

  test 'offset returns the next page and the total counts all candidates' do
    source = product('Source', sub_categories: [@amps], release_year: 2000)
    candidates = Array.new(5) do |index|
      product("Candidate #{index}", sub_categories: [@amps], release_year: 2000 + index)
    end

    assert_equal candidates[2..3].map(&:id), ranked(source, limit: 2, offset: 2)
    assert_equal 5, query(source, limit: 2, offset: 2).total_count
  end

  test 'a page after the last one is empty but still has the total' do
    source = product('Source', sub_categories: [@amps])
    3.times { |index| product("Candidate #{index}", sub_categories: [@amps]) }

    result = query(source, limit: 2, offset: 10)

    assert_empty result.ids
    assert_equal 3, result.total_count
  end

  test 'the total does not count candidates below the minimum score' do
    others = Array.new(10) { |index| sub_category("Extra #{index}") }
    source = product('Source', sub_categories: [@amps])
    product('Match', sub_categories: [@amps])
    product('Weak', sub_categories: [@amps, *others])

    assert_equal 1, query(source).total_count
  end
end
