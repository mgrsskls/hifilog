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
end
