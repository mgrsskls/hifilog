require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  test 'active_menu_state' do
    assert_equal active_menu_state('page1', 'page1'), ' aria-current=true'
    assert_equal active_menu_state('page1', 'page2'), ' aria-current=false'
  end

  test 'formatted_date' do
    assert_equal formatted_date(Time.zone.local(2000, 1, 1)), '2000-01-01T00:00+0000'
  end

  test 'formatted_datetime' do
    assert_equal formatted_datetime(Time.zone.local(2000, 1, 1, 12, 30)), '2000-01-01T12:30+0000'
  end

  test 'user_has_product?' do
    assert_not user_has_product?(nil, products(:one))
    assert user_has_product?(users(:one), products(:one))
    assert_not user_has_product?(users(:without_anything), products(:one))
  end

  test 'user_has_previously_owned?' do
    assert_not user_has_previously_owned?(nil, products(:two))
    assert user_has_previously_owned?(users(:one), products(:two))
    assert_not user_has_previously_owned?(users(:without_anything), products(:two))
  end

  test 'user_has_bookmark?' do
    assert_not user_has_bookmark?(nil, products(:one))
    assert user_has_bookmark?(users(:one), products(:one))
    assert_not user_has_bookmark?(users(:without_anything), products(:one))
  end

  test 'user_has_brand?' do
    assert_not user_has_brand?(nil, brands(:one), false)

    assert user_has_brand?(users(:one), brands(:one), false)
    assert_not user_has_brand?(users(:without_anything), brands(:one), false)

    assert user_has_brand?(users(:one), brands(:two), true)
    assert_not user_has_brand?(users(:without_anything), brands(:two), true)
  end

  test 'user_possessions_count' do
    assert_nil user_possessions_count(nil)
    assert_equal user_possessions_count(users(:one)), 3
    assert_equal user_possessions_count(users(:without_anything)), 0
  end

  test 'user_bookmarks_count' do
    assert_nil user_bookmarks_count(nil)
    assert_equal user_bookmarks_count(users(:one)), 2
    assert_equal user_bookmarks_count(users(:without_anything)), 0
  end

  test 'user_setups_count' do
    assert_nil user_setups_count(nil)
    assert_equal user_setups_count(users(:one)), 2
    assert_equal user_setups_count(users(:without_anything)), 0
  end

  test 'user_custom_products_count' do
    assert_nil user_custom_products_count(nil)
    assert_equal user_custom_products_count(users(:one)), 3
    assert_equal user_custom_products_count(users(:without_anything)), 0
  end

  test 'user_prev_owneds_count' do
    assert_nil user_prev_owneds_count(nil)
    assert_equal user_prev_owneds_count(users(:one)), 3
    assert_equal user_prev_owneds_count(users(:without_anything)), 0
  end

  test 'user_notes_count' do
    assert_nil user_notes_count(nil)
    assert_equal user_notes_count(users(:one)), 1
    assert_equal user_notes_count(users(:without_anything)), 0
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

  test 'country_name_from_country_code' do
    assert_nil country_name_from_country_code(nil)
    assert_nil country_name_from_country_code(:xyz)
    assert_equal 'Germany', country_name_from_country_code(:de)
  end

  test 'custom_attributes_list' do
    assert_nil custom_attributes_list(products(:without_custom_attributes))
    assert_equal 'Stereo, Direct Drive', custom_attributes_list(products(:with_custom_attributes))
  end
end
