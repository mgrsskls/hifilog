# frozen_string_literal: true

require 'test_helper'

class ImportCategoryMappingTest < ActiveSupport::TestCase
  test 'a mapping must decide something' do
    empty = ImportCategoryMapping.new(source_category: 'Verstärker')

    assert_not empty.valid?, 'a mapping that names no sub category and refuses nothing decides nothing'

    empty.out_of_scope = true

    assert_predicate empty, :valid?
  end

  test 'one decision per word per brand' do
    ImportCategoryMapping.create!(source_category: 'Amplifiers', sub_category_ids: [sub_categories(:one).id])
    second = ImportCategoryMapping.new(source_category: 'amplifiers', sub_category_ids: [sub_categories(:two).id])

    assert_not second.valid?, 'the same word must not have two general answers'
  end

  test "a brand's own decision wins over the general one" do
    general = ImportCategoryMapping.create!(
      source_category: 'Reference', sub_category_ids: [sub_categories(:one).id]
    )
    own = ImportCategoryMapping.create!(
      brand: brands(:one), source_category: 'Reference', sub_category_ids: [sub_categories(:two).id]
    )

    assert_equal own, ImportCategoryMapping.for(brands(:one).id, 'Reference')
    assert_equal general, ImportCategoryMapping.for(brands(:two).id, 'Reference')
  end

  test 'a word may be refused rather than mapped' do
    mapping = ImportCategoryMapping.create!(source_category: 'Vinyl', out_of_scope: true)

    assert_predicate mapping, :out_of_scope?
    assert_empty mapping.sub_categories
  end

  test 'a word may name more than one sub category' do
    # "In-Wall Subwoofers" is one word for two things, and both are right.
    mapping = ImportCategoryMapping.create!(
      source_category: 'In-Wall Subwoofers',
      sub_category_ids: [sub_categories(:one).id, sub_categories(:two).id]
    )

    assert_equal 2, mapping.sub_categories.count
  end

  test 'a sub category that does not exist is refused' do
    mapping = ImportCategoryMapping.new(source_category: 'Verstärker', sub_category_ids: [-1])

    assert_not mapping.valid?
  end
end
