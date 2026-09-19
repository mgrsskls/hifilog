# frozen_string_literal: true

require 'test_helper'

# The weights refer to attributes by label. A label that does not exist gives 0 points and no
# error, so these tests find a misspelled or removed label.
class SimilarProducts::WeightsTest < ActiveSupport::TestCase
  LABELS = I18n.t('custom_attribute_labels').keys.map(&:to_s)

  test 'every categorical attribute label exists' do
    missing = SimilarProducts::Weights::ATTRIBUTES.keys - LABELS

    assert_empty missing
  end

  test 'every numeric attribute label exists' do
    missing = SimilarProducts::Weights::NUMERIC_CLASSES.keys - LABELS

    assert_empty missing
  end

  test 'an attribute is either categorical or numeric, not both' do
    both = SimilarProducts::Weights::ATTRIBUTES.keys & SimilarProducts::Weights::NUMERIC_CLASSES.keys

    assert_empty both
  end

  test 'numeric class limits are ascending' do
    SimilarProducts::Weights::NUMERIC_CLASSES.each do |label, config|
      assert_equal config[:limits].sort, config[:limits], label
    end
  end
end
