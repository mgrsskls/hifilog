# frozen_string_literal: true

require 'test_helper'

# An option saved in ActiveAdmin has no save of its product, so ActiveAdmin records the version.
class AdminProductOptionsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in admin_users(:admin_user)
    @product = products(:one)
  end

  test 'a new option creates a version of its product' do
    assert_difference -> { @product.versions.count }, 1 do
      post admin_product_options_path, params: { product_option: { product_id: @product.id, option: 'Admin option' } }
    end

    assert_includes @product.versions.last.association_changes['product_options'].last, 'Admin option'
  end

  test 'moving an option to another product creates a version of both products' do
    other = products(:two)

    assert_difference [-> { @product.versions.count }, -> { other.versions.count }], 1 do
      patch admin_product_option_path(product_options(:one)), params: { product_option: { product_id: other.id } }
    end
  end

  test 'a deleted option creates a version of its product' do
    assert_difference -> { @product.versions.count }, 1 do
      delete admin_product_option_path(product_options(:one))
    end

    assert_not_includes @product.versions.last.association_changes['product_options'].last, 'MyString'
  end
end
