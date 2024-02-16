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

  test 'round_up_or_down' do
    assert_equal round_up_or_down(12), { value: 12, dir: :eq }
    assert_equal round_up_or_down(16), { value: 16, dir: :eq }
    assert_equal round_up_or_down(930), { value: 930, dir: :eq }
    assert_equal round_up_or_down(2000), { value: 2000, dir: :eq }
    assert_equal round_up_or_down(15_000), { value: 15_000, dir: :eq }
    assert_equal round_up_or_down(934), { value: 930, dir: :down }
    assert_equal round_up_or_down(73_123), { value: 73_000, dir: :down }
    assert_equal round_up_or_down(100_523_934), { value: 100_000_000, dir: :down }
    assert_equal round_up_or_down(193_523_934), { value: 190_000_000, dir: :down }
    assert_equal round_up_or_down(978), { value: 980, dir: :up }
    assert_equal round_up_or_down(99_600), { value: 100_000, dir: :up }
    assert_equal round_up_or_down(198_523_934), { value: 200_000_000, dir: :up }
  end
end
