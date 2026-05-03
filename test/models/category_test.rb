# frozen_string_literal: true

require 'test_helper'

class CategoryTest < ActiveSupport::TestCase
  def with_memory_cache
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = previous
  end

  test 'requires name' do
    category = Category.new(name: '   ', slug: 'x')
    assert_not category.valid?
    assert category.errors.attribute_names.include?(:name)
  end

  test 'requires unique name' do
    existing = categories(:one)
    duplicate = Category.new(name: existing.name, slug: 'unique-slug-xyz')
    assert_not duplicate.valid?
    assert duplicate.errors.attribute_names.include?(:name)
  end

  test 'auto strips and squishes name' do
    category = Category.create!(name: "  New \n Name  ", slug: 'new-name-xyz', order: 99)
    assert_equal 'New Name', category.reload.name
  ensure
    category&.destroy
  end

  test 'save invalidates menu and category count cache keys' do
    with_memory_cache do
      Rails.cache.write('/menu_categories', 'stale')
      Rails.cache.write('/categories_count', 0)

      category = Category.create!(name: 'Cache Cat Name', slug: 'cache-cat-xyz', order: 99)

      assert_nil Rails.cache.read('/menu_categories')
      assert_nil Rails.cache.read('/categories_count')
    ensure
      category&.destroy
    end
  end

  test 'destroy invalidates menu and category count cache keys' do
    with_memory_cache do
      category = Category.create!(name: 'Destroy Cat', slug: 'destroy-cat-xyz', order: 98)

      Rails.cache.write('/menu_categories', 'stale')
      Rails.cache.write('/categories_count', 1)

      category.destroy!

      assert_nil Rails.cache.read('/menu_categories')
      assert_nil Rails.cache.read('/categories_count')
    end
  end
end
