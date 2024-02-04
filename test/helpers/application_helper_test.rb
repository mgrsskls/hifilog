require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  test 'user_has_product?' do
    assert_not user_has_product?(nil, products(:one))

    assert user_has_product?(users(:one), products(:one))

    assert_not user_has_product?(users(:two), products(:one))
  end

  test 'user_has_bookmark?' do
    assert_not user_has_bookmark?(nil, products(:one))

    assert user_has_bookmark?(users(:one), products(:one))
    assert_not user_has_bookmark?(users(:two), products(:one))
  end

  test 'user_has_brand?' do
    assert_not user_has_brand?(nil, brands(:one))

    assert user_has_brand?(users(:one), brands(:one))
    assert_not user_has_brand?(users(:two), brands(:one))
  end

  test 'user_products_count' do
    assert_nil user_products_count(nil)
    assert_equal user_products_count(users(:one)), 2
    assert_equal user_products_count(users(:two)), 0
  end

  test 'user_bookmarks_count' do
    assert_nil user_bookmarks_count(nil)
    assert_equal user_bookmarks_count(users(:one)), 2
    assert_equal user_bookmarks_count(users(:two)), 0
  end

  test 'user_setups_count' do
    assert_nil user_setups_count(nil)
    assert_equal user_setups_count(users(:one)), 2
    assert_equal user_setups_count(users(:two)), 0
  end

  test 'rounddown' do
    assert_equal rounddown(12), 10
    assert_equal rounddown(934), 900
    assert_equal rounddown(100_523_934), 100_000_000
  end
end
