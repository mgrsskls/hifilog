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

  test 'preload_list_possession_images batches possession loads for list thumbnails' do
    rows = ProductItem.where(item_type: 'Product').limit(3).to_a
    skip 'need at least two product rows' if rows.size < 2

    relation = ProductItem.preload_list_possession_images(ProductItem.where(id: rows.map(&:id)))

    possession_queries = count_possession_queries do
      relation.each(&:list_possessions_for_thumbnail)
    end

    assert_equal 0, possession_queries
  end

  test 'chaining preload on paginated relation after preload_list_possession_images reloads rows' do
    rows = ProductItem.where(item_type: 'Product').limit(2).to_a
    skip 'need at least two product rows' if rows.size < 2

    page = ProductItem.preload_list_possession_images(
      ProductItem.where(id: rows.map(&:id)).page(1).per(rows.size)
    )

    preloaded_row = page.records.first
    reloaded_row = page.preload(:brand).find { |row| row.id == preloaded_row.id }

    assert_predicate preloaded_row.base_product_possessions, :loaded?
    assert_not_predicate reloaded_row.base_product_possessions, :loaded?
  end

  test 'list_image_cache_version yields none without matching thumbnail possessions' do
    row = ProductItem.find_by(item_type: 'Product', product_id: products(:without_custom_attributes).id)
    skip 'product_items view row unavailable in this suite' unless row

    row.define_singleton_method(:earliest_list_possession_with_images) { |_args| nil }
    assert_equal 'none', row.list_image_cache_version(user_signed_in: false)
  end

  private

  def count_possession_queries(&)
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      count += 1 if payload[:sql].match?(/\bFROM "possessions"\b/i)
    end

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end
end
