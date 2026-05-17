# frozen_string_literal: true

require 'test_helper'

class CustomProductTest < ActiveSupport::TestCase
  test 'name presence validation' do
    custom_product = CustomProduct.new(user_id: users(:one).id)
    assert_not custom_product.valid?
    assert custom_product.errors[:name].any?
  end

  test 'name uniqueness per user' do
    user = users(:one)
    custom_product1 = custom_products(:one)
    custom_product2 = CustomProduct.new(
      name: custom_product1.name,
      user_id: user.id,
      sub_category_ids: [sub_categories(:one).id]
    )
    assert_not custom_product2.valid?
    assert custom_product2.errors[:name].any?
  end

  test 'name can be duplicate across users' do
    custom_product1 = custom_products(:one)
    custom_product2 = CustomProduct.new(
      name: custom_product1.name,
      user_id: users(:hidden).id,
      sub_category_ids: [sub_categories(:one).id]
    )
    assert custom_product2.valid?
  end

  test 'sub_categories presence validation' do
    custom_product = CustomProduct.new(name: 'Test', user_id: users(:one).id)
    assert_not custom_product.valid?
    assert custom_product.errors[:sub_categories].any?
  end

  test 'custom_attributes method' do
    custom_product = custom_products(:one)
    assert_equal({}, custom_product.custom_attributes)
  end

  test 'associations' do
    custom_product = custom_products(:one)
    assert_respond_to custom_product, :user
    assert_respond_to custom_product, :possession
    assert_respond_to custom_product, :sub_categories
    assert_respond_to custom_product, :images
  end

  test 'friendly_id reflects stored slug' do
    custom_product = custom_products(:one)
    assert_equal 'name', custom_product.slug
    assert_equal 'name', custom_product.friendly_id

    other = CustomProduct.create!(
      name: custom_product.name,
      user: users(:hidden),
      sub_category_ids: [sub_categories(:one).id]
    )
    assert_equal 'name', other.slug
  end

  test 'renaming preserves previous slug in history' do
    custom_product = custom_products(:one)
    user = custom_product.user
    old_slug = custom_product.slug

    custom_product.update!(name: 'Renamed custom product title')

    custom_product.reload
    assert_equal 'renamed-custom-product-title', custom_product.slug
    assert FriendlyId::Slug.exists?(slug: old_slug, sluggable: custom_product)
    assert user.custom_products.friendly.find(old_slug)
  end
end
