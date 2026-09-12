# frozen_string_literal: true

require 'test_helper'

class SubCategoryTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
  # `identifier` exists because `slug` follows `name` -- FriendlyId regenerates it on rename --
  # while RelatedProducts::Graph needs a reference that survives a display rename.
  test 'identifier is derived from the name on create' do
    sub_category = SubCategory.create!(name: 'Reel To Reel Decks', category: categories(:one))

    assert_equal 'reel-to-reel-decks', sub_category.identifier
  end

  test 'identifier is unique across categories, not just within one' do
    first = SubCategory.create!(name: 'Splitters', category: categories(:one))
    second = SubCategory.create!(name: 'Splitters', category: categories(:two))

    assert_equal 'splitters', first.identifier
    assert_equal 'splitters-2', second.identifier
  end

  test 'identifier cannot be changed once set' do
    sub_category = sub_categories(:one)
    sub_category.identifier = 'something-else'

    assert_not sub_category.valid?
    assert_includes sub_category.errors[:identifier].join, 'cannot be changed'
  end

  test 'renaming leaves the identifier alone even though the slug follows' do
    sub_category = SubCategory.create!(name: 'Tape Loops', category: categories(:one))
    original = sub_category.identifier

    sub_category.update!(name: 'Tape Loop Accessories')

    assert_equal original, sub_category.reload.identifier
    assert_equal 'tape-loop-accessories', sub_category.slug
  end
end
