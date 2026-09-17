# frozen_string_literal: true

require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  test 'index for logged out user' do
    get root_url
    assert_response :success
  end

  test 'index shows the newest catalogue entries as cards' do
    get root_url

    assert_select 'ol.HomeCards .HomeCard', minimum: 1
    assert_select '.HomeCard-name', minimum: 1
  end

  test 'index shows upcoming events and skips past ones' do
    get root_url

    assert_select '.Home-events .EntityList--events .EntityListItem--event', minimum: 1
    assert_select '.Home-events .EntityListItem-name' do |names|
      assert_not_includes names.map { |name| name.text.strip }, events(:one).name
    end
  end

  test 'index shows the totals band' do
    get root_url

    assert_select '.HomeNumbers .HomeNumbers-item', minimum: 1
  end

  test 'index renders no empty section when a block has nothing to show' do
    Possession.destroy_all

    get root_url

    assert_response :success
    assert_select '.Home-photos', count: 0
  end

  test 'index for logged in user redirects to dashboard' do
    sign_in users(:one)
    get root_url
    assert_response :redirect
    assert_redirected_to dashboard_root_path
  end
end
