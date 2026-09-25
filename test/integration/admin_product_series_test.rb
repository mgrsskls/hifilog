# frozen_string_literal: true

require 'test_helper'

# The admin URLs of a series use its id: the slug is unique only within the brand.
class AdminProductSeriesTest < ActionDispatch::IntegrationTest
  setup do
    sign_in admin_users(:admin_user)
    @series = ProductSeries.create!(brand: brands(:one), name: "Admin #{SecureRandom.hex(3)}")
  end

  test 'the index links to the series by id' do
    get admin_product_series_index_path

    assert_response :success
    assert_select "a[href='#{admin_product_series_path(@series)}']"
    assert_equal "/admin/product_series/#{@series.id}", admin_product_series_path(@series)
  end

  test 'show, edit and update find the series' do
    get admin_product_series_path(@series)
    assert_response :success

    get edit_admin_product_series_path(@series)
    assert_response :success

    patch admin_product_series_path(@series), params: { product_series: { description: 'From the admin' } }
    assert_redirected_to admin_product_series_path(@series)
    assert_equal 'From the admin', @series.reload.description
  end

  test 'delete removes the series and records the removal on its products' do
    product = Product.create!(name: "In series #{SecureRandom.hex(3)}", brand: brands(:one),
                              product_series: @series, sub_categories: [sub_categories(:one)])

    delete admin_product_series_path(@series)

    assert_redirected_to admin_product_series_index_path
    assert_not ProductSeries.exists?(@series.id)
    assert_equal [@series.id, nil], product.versions.last.changeset['product_series_id']
  end
end
