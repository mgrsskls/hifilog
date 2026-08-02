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

  test 'sub_category_names raises rather than reporting no categories when the preload was skipped' do
    row = ProductItem.find_by(item_type: 'Product', product_id: products(:one).id)
    skip 'product_items view row unavailable in this suite' unless row

    error = assert_raises(RuntimeError) { row.sub_category_names }

    assert_match(/preload_sub_category_names/, error.message)
  end

  test 'sub_category_names is empty for a product with no sub categories once preloaded' do
    # Product validates sub_categories presence on save, so `update!(sub_categories: [])` can't
    # produce this state — .clear bypasses that (skips Product's own validations) to simulate it.
    products(:one).sub_categories.clear
    row = ProductItem.find_by(item_type: 'Product', product_id: products(:one).id)
    skip 'product_items view row unavailable in this suite' unless row

    relation = ProductItem.preload_sub_category_names(ProductItem.where(id: row.id))

    assert_equal [], relation.first.sub_category_names
  end

  test 'preload_sub_category_names batches names for product and variant rows by their product_id' do
    products(:one).update!(sub_categories: [sub_categories(:one)])
    # product_variants(:one) belongs to products(:with_variants), which the fixture already
    # associates with sub_categories(:two) — used here to prove grouping is keyed by product_id,
    # not shared across unrelated rows in the same batch.

    product_row = ProductItem.find_by(item_type: 'Product', product_id: products(:one).id)
    variant_row = ProductItem.find_by(item_type: 'ProductVariant', product_variant_id: product_variants(:one).id)
    skip 'product_items view rows unavailable in this suite' unless product_row && variant_row

    relation = ProductItem.where(id: [product_row.id, variant_row.id])
    same = ProductItem.preload_sub_category_names(relation)

    assert_same relation, same
    assert_equal [sub_categories(:one).name],
                 relation.find { |row| row.id == product_row.id }.sub_category_names
    assert_equal [sub_categories(:two).name],
                 relation.find { |row| row.id == variant_row.id }.sub_category_names
  end

  test 'preload_sub_category_names issues a single query regardless of page size' do
    products(:one).update!(sub_categories: [sub_categories(:one)])
    rows = ProductItem.where(item_type: 'Product').limit(3).to_a
    skip 'need at least two product rows' if rows.size < 2

    relation = ProductItem.preload_sub_category_names(ProductItem.where(id: rows.map(&:id)))

    sub_category_queries = count_sub_category_queries do
      relation.each(&:sub_category_names)
    end

    assert_equal 1, sub_category_queries
  end

  # shared/_products_table reads sub_category_names inside a per-row fragment cache, so a fully
  # cached page must not pay for the preload at all.
  test 'preload_sub_category_names issues no query until the names are actually read' do
    rows = ProductItem.where(item_type: 'Product').limit(3).to_a
    skip 'need at least two product rows' if rows.size < 2

    sub_category_queries = count_sub_category_queries do
      ProductItem.preload_sub_category_names(ProductItem.where(id: rows.map(&:id)))
    end

    assert_equal 0, sub_category_queries
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

  def count_sub_category_queries(&)
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      count += 1 if payload[:sql].match?(/FROM "sub_categories"/i)
    end

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end
end
