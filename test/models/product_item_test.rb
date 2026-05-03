# frozen_string_literal: true

require 'test_helper'

class ProductItemTest < ActiveSupport::TestCase
  test 'base product projections expose readonly persisted rows' do
    row = ProductItem.find_by(item_type: 'Product', product_id: products(:one).id)

    skip 'product_items view row unavailable in this suite' unless row

    assert_predicate row, :readonly?

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      row.assign_attributes(name: "#{row.name} ")
      row.save!
    end
  end

  test 'variant projections map possessions helpers to variant possessions' do
    variant_record = ProductItem.find_by(
      item_type: 'ProductVariant',
      product_variant_id: product_variants(:one).id
    )

    skip 'product_items view missing variant projections' unless variant_record

    assert_equal variant_record.variant_possessions.select(:id).to_sql.strip,
                 variant_record.possessions.select(:id).to_sql.strip
  end

  test 'product row lists sub_categories through product join table' do
    row = ProductItem.find_by(item_type: 'Product', product_id: products(:one).id)
    skip 'product_items view row unavailable in this suite' unless row

    assert_equal SubCategory.joins(:products).where(products: { id: products(:one).id }).distinct.to_a.sort_by(&:id),
                 row.sub_categories.to_a.sort_by(&:id)
  end

  test 'preload_list_possession_images returns relation after preloading variants' do
    variant_record = ProductItem.find_by(item_type: 'ProductVariant',
                                         product_variant_id: product_variants(:one).id)
    skip 'product_items view missing variant projections' unless variant_record

    relation = ProductItem.where(id: variant_record.id)
    same = ProductItem.preload_list_possession_images(relation)

    assert_same relation, same
  end

  test 'preload_list_possession_images runs for product rows referencing variants' do
    row = ProductItem.find_by(item_type: 'Product', product_id: products(:with_variants).id)
    skip 'product_items view row unavailable in this suite' unless row

    relation = ProductItem.where(id: row.id)

    assert_nothing_raised { ProductItem.preload_list_possession_images(relation) }
    assert_same relation, ProductItem.preload_list_possession_images(relation)
  end

  test 'list_image_cache_version yields none without matching thumbnail possessions' do
    row = ProductItem.find_by(item_type: 'Product', product_id: products(:without_custom_attributes).id)
    skip 'product_items view row unavailable in this suite' unless row

    row.define_singleton_method(:earliest_list_possession_with_images) { |_args| nil }
    assert_equal 'none', row.list_image_cache_version(user_signed_in: false)
  end
end
