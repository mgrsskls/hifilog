require 'test_helper'

class ProductTest < ActiveSupport::TestCase
  test 'release_date' do
    assert_equal '2020/06/01', products(:release_date_ymd).formatted_release_date
    assert_equal '2020/06', products(:release_date_ym).formatted_release_date
    assert_equal '2020', products(:release_date_yd).formatted_release_date
    assert_nil products(:release_date_md).formatted_release_date
    assert_equal '2020', products(:release_date_y).formatted_release_date
    assert_nil products(:release_date_m).formatted_release_date
    assert_nil products(:release_date_d).formatted_release_date
  end

  test 'display_name' do
    product = Product.new(name: 'product_name')

    assert_equal 'product_name', product.display_name
    assert_equal 'Feliks Audio Elise', products(:one).display_name
  end

  test 'url_slug' do
    assert_equal 'feliks-audio-elise', products(:one).url_slug
  end
end
