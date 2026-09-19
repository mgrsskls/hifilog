# frozen_string_literal: true

require 'test_helper'

# The series field of the product form (docs/product-series.md).
class ProductsSeriesFormTest < ActionDispatch::IntegrationTest
  setup do
    @brand = brands(:one)
    sign_in users(:one)
  end

  def create_params(name, series_name)
    {
      product: {
        name:,
        brand_id: @brand.id,
        discontinued: false,
        sub_category_ids: [sub_categories(:one).id],
        product_series_name: series_name
      }
    }
  end

  test 'new preselects the series from the series page link' do
    get new_product_path(brand_id: @brand.id, series: product_series(:evolution).slug)

    assert_response :success
    assert_select 'input[name="product[product_series_name]"][value=?]', 'Evolution'
    assert_select 'datalist#product-series-options option[value=?]', 'Legacy'
  end

  test 'create with an existing series' do
    name = "Series Form #{SecureRandom.hex(3)}"

    post products_url, params: create_params(name, 'Evolution')

    product = Product.find_by!(name:)
    assert_equal product_series(:evolution), product.product_series
    assert_redirected_to product_url(id: product.friendly_id)
  end

  test 'create with a new series creates it for the brand' do
    name = "New Series Form #{SecureRandom.hex(3)}"

    assert_difference 'ProductSeries.count', 1 do
      post products_url, params: create_params(name, 'Signature')
    end

    assert_equal 'Signature', Product.find_by!(name:).product_series.name
  end

  test 'create with the series name in the product name renders the form again' do
    assert_no_difference 'Product.count' do
      post products_url, params: create_params("Evolution Omega #{SecureRandom.hex(3)}", 'Evolution')
    end

    assert_response :unprocessable_content
  end

  test 'update removes the series with an empty field' do
    product = Product.create!(name: "Update Series #{SecureRandom.hex(3)}", brand: @brand,
                              product_series: product_series(:evolution), sub_categories: [sub_categories(:one)])

    patch product_url(id: product.id), params: { product: { product_series_name: '' } }

    assert_nil product.reload.product_series
  end
end
