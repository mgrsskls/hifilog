# frozen_string_literal: true

require 'test_helper'

class SubCategoryCompletenessJobTest < ActiveJob::TestCase
  setup do
    @product = products(:one)
    @sub_category_id = @product.sub_category_ids.first
  end

  test 'recalculates the completeness of the products in the sub category' do
    make_completeness_wrong(@product)

    SubCategoryCompletenessJob.perform_now(@sub_category_id)

    @product.reload
    assert_equal @product.completeness_score, @product.completeness
    assert_equal @product.applicable_highlighted_attributes.size, @product.specs_applicable
  end

  # The job gives its cursor as `start`. A resumed job must not do the products before it again.
  test 'skips the products before the start id' do
    make_completeness_wrong(@product)

    Product.recalculate_completeness_for_sub_category!(@sub_category_id, start: @product.id + 1)

    assert_equal 99, @product.reload.specs_applicable
  end

  test 'enqueues one job for each sub category' do
    assert_enqueued_jobs 2, only: SubCategoryCompletenessJob do
      Product.recalculate_completeness_for_sub_categories_later([1, 2, 1])
    end
  end

  test 'enqueues nothing without sub categories' do
    assert_no_enqueued_jobs do
      Product.recalculate_completeness_for_sub_categories_later([])
    end
  end

  private

  def make_completeness_wrong(product)
    wrong = product.completeness_score.zero? ? 1 : 0
    product.update_columns(completeness: wrong, specs_applicable: 99, specs_filled: 99) # rubocop:disable Rails/SkipsModelValidations
  end
end
