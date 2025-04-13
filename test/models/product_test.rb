require 'test_helper'

class ProductTest < ActiveSupport::TestCase
  test 'release_date' do
    assert_equal '2020&thinsp;/&thinsp;06&thinsp;/&thinsp;01', products(:release_date_ymd).formatted_release_date
    assert_equal '2020&thinsp;/&thinsp;06', products(:release_date_ym).formatted_release_date
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

  test 'custom_attributes_list' do
    assert_nil products(:without_custom_attributes).custom_attributes_list
    assert_equal 'Stereo, Direct Drive', products(:with_custom_attributes).custom_attributes_list
  end
end
