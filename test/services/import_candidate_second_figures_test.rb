# frozen_string_literal: true

require 'test_helper'

class ImportCandidateSecondFiguresTest < ActiveSupport::TestCase
  setup do
    custom_attributes(:four).update!(units: %w[lb kg])
  end

  test 'adds the imperial figure the snippet states next to the stored one' do
    record = candidate('weight', { 'value' => 16, 'unit' => 'kg' }, 'Weight: 16 kg / 35 lbs')

    ImportCandidateSecondFigures.new.call(apply: true)

    assert_equal({ 'value' => 16, 'unit' => 'kg', 'second' => { 'value' => 35.0, 'unit' => 'lb' } },
                 record.reload.custom_attributes['weight'])
  end

  test 'maps a second set of dimensions onto the stored inputs by position' do
    record = candidate('dimensions', { 'value' => { 'h' => 4, 'l' => 8, 'w' => 12.5 }, 'unit' => 'cm' },
                       'Dimensions (W × D × H): 125 × 80 × 40 mm / 4.92 × 3.15 × 1.57 in')

    ImportCandidateSecondFigures.new.call(apply: true)

    assert_equal({ 'value' => { 'h' => 1.57, 'l' => 3.15, 'w' => 4.92 }, 'unit' => 'in' },
                 record.reload.custom_attributes.dig('dimensions', 'second'))
  end

  test 'warns instead when the two figures disagree' do
    record = candidate('weight', { 'value' => 15, 'unit' => 'kg' }, 'Weight: 15 kg / 22 lbs')

    2.times { ImportCandidateSecondFigures.new.call(apply: true) }

    record.reload
    assert_not record.custom_attributes['weight'].key?('second')
    assert_equal ['weight: the stated figures disagree (15 kg / 22 lb), no second figure added'], record.warnings
  end

  test 'skips a snippet that does not state the stored figure or states one figure only' do
    candidate('weight', { 'value' => 16, 'unit' => 'kg' }, 'Weight: 17 kg / 37 lbs')
    candidate('weight', { 'value' => 16, 'unit' => 'kg' }, 'Weight: 16 kg')

    assert_empty ImportCandidateSecondFigures.new.call
  end

  test 'writes nothing without apply' do
    record = candidate('weight', { 'value' => 16, 'unit' => 'kg' }, 'Weight: 16 kg / 35 lbs')

    results = ImportCandidateSecondFigures.new.call

    assert_equal [:added], results.map(&:outcome)
    assert_not record.reload.custom_attributes['weight'].key?('second')
  end

  private

  def candidate(label, entry, snippet)
    ImportCandidate.create!(
      brand: brands(:one),
      brand_slug: brands(:one).slug,
      name: 'Second figure test',
      source_url: "https://example.com/products/#{SecureRandom.hex(4)}",
      status: 'pending',
      custom_attributes: { label => entry },
      provenance: { "custom_attributes.#{label}" => { 'source' => 'spec_list', 'snippet' => snippet } }
    )
  end
end
