# frozen_string_literal: true

require 'test_helper'

# What is tested here is the part that protects the catalogue: a candidate must
# not turn into a product that nobody approved, a duplicate must be visible
# before it is created, and a decision must survive the next import run.
class ImportCandidateTest < ActiveSupport::TestCase
  def candidate(**overrides)
    ImportCandidate.new(
      {
        brand: brands(:one),
        brand_slug: brands(:one).slug,
        name: 'Euforia',
        source_url: 'https://feliksaudio.pl/products/euforia',
        provenance: { 'name' => { 'source' => 'jsonld', 'confidence' => 0.95 } },
        score: 0.6
      }.merge(overrides)
    )
  end

  test 'a candidate needs a name, a brand slug and a source' do
    assert candidate.valid?
    assert_not candidate(name: nil).valid?
    assert_not candidate(brand_slug: nil).valid?
    assert_not candidate(source_url: nil).valid?
  end

  test 'one row per product page per brand' do
    candidate.save!
    second = candidate

    assert_not second.valid?, 'the same page must not become two candidates'
  end

  # `rake import:load` writes with upsert_all. A jsonb column given a String
  # stores one JSON string, and the review screen then fails on `provenance`.
  test 'an upsert keeps the jsonb columns as objects' do
    # rubocop:disable Rails/SkipsModelValidations -- upsert_all is exactly what's under test
    ImportCandidate.upsert_all(
      [{ brand_slug: brands(:one).slug, name: 'Euforia', source_url: 'https://feliksaudio.pl/p/e',
         provenance: { 'name' => { 'source' => 'jsonld' } }, variants: [{ 'name' => 'Black' }],
         custom_attributes: {}, created_at: Time.current, updated_at: Time.current }],
      unique_by: [:brand_slug, :source_url]
    )
    # rubocop:enable Rails/SkipsModelValidations
    stored = ImportCandidate.find_by!(source_url: 'https://feliksaudio.pl/p/e')

    assert_equal 'jsonld', stored.provenance.dig('name', 'source')
    assert_equal 'Black', stored.variants.first['name']
  end

  test 'the empty value of a check box form is not stored as a sub category' do
    record = candidate(sub_category_ids: ['', '3', '3', '5'])

    assert_equal [3, 5], record.sub_category_ids
  end

  test 'an edited candidate is not untouched any more' do
    record = candidate
    record.save!

    assert_includes ImportCandidate.untouched, record

    record.update!(edited_at: Time.current)

    assert_predicate record, :edited?
    assert_not_includes ImportCandidate.untouched, record
  end

  test 'a verdict that decided the sub categories closes the row to the mappings' do
    open_rows = [nil, 'agreed', 'unsure'].map.with_index do |verdict, index|
      candidate(source_url: "https://example.test/open-#{index}", validation_verdict: verdict).tap(&:save!)
    end
    closed_rows = %w[corrected classified no_category out_of_scope].map.with_index do |verdict, index|
      candidate(source_url: "https://example.test/closed-#{index}", validation_verdict: verdict).tap(&:save!)
    end

    open_rows.each { |record| assert_includes ImportCandidate.open_to_mapping, record }
    closed_rows.each { |record| assert_not_includes ImportCandidate.open_to_mapping, record }
  end

  test 'a new candidate waits for a person' do
    assert_predicate candidate, :pending?
  end

  test 'a candidate may name more than one sub category' do
    # The Wisdom Audio SUB1 is a subwoofer and an in-wall loudspeaker. A
    # proposal that could hold one would have to be wrong for such a product.
    both = candidate(sub_category_ids: [sub_categories(:one).id, sub_categories(:two).id])
    both.save!

    assert_equal 2, both.sub_categories.count
    assert_predicate both, :classified?
    assert_includes ImportCandidate.classified, both
    assert_not_includes ImportCandidate.unclassified, both
  end

  test 'a candidate with no sub category is unclassified' do
    plain = candidate
    plain.save!

    assert_not_predicate plain, :classified?
    assert_includes ImportCandidate.unclassified, plain
  end

  test 'a candidate is found by any of its sub categories' do
    both = candidate(sub_category_ids: [sub_categories(:one).id, sub_categories(:two).id])
    both.save!

    assert_includes ImportCandidate.of_sub_category(sub_categories(:two).id), both
  end

  test 'the brand may be unknown and the row still waits' do
    # A slug that matches no brand is a question for the review. Dropping the
    # row would lose the work of the crawl for a brand that may be added later.
    orphan = candidate(brand: nil, brand_slug: 'brand-not-in-the-catalogue')

    assert_predicate orphan, :valid?
    assert_empty orphan.possible_duplicates
  end

  test 'an existing product with the same model number is found' do
    product = products(:one)
    match = candidate(brand: product.brand, model_no: product.model_no)

    skip 'the fixture product has no model number' if product.model_no.blank?
    assert_includes match.possible_duplicates, product
  end

  test 'an existing product with the same name is found' do
    product = products(:one)
    match = candidate(brand: product.brand, name: product.name.downcase, model_no: nil)

    assert_includes match.possible_duplicates, product
  end

  test 'the provenance of a field is readable per field' do
    assert_equal 'jsonld', candidate.source_for(:name)['source']
    assert_in_delta 0.95, candidate.confidence_for(:name)
    assert_empty candidate.source_for(:price)
  end

  test 'the display name holds the version words apart from the name' do
    assert_equal 'Euforia Walnut', candidate(variant_name: 'Walnut').display_name
    assert_equal 'Euforia', candidate.display_name
  end

  test 'unmapped categories leave out the words that are already decided' do
    candidate(source_category: 'Kopfhörerverstärker').save!
    pairs = ImportCandidate.unmapped_categories

    assert(pairs.any? { |(_brand_id, word), _count| word == 'Kopfhörerverstärker' })

    ImportCategoryMapping.create!(
      brand: brands(:one),
      source_category: 'Kopfhörerverstärker',
      sub_category_ids: [sub_categories(:one).id]
    )

    assert_empty(ImportCandidate.unmapped_categories.select { |(_id, word), _c| word == 'Kopfhörerverstärker' })
  end
end
