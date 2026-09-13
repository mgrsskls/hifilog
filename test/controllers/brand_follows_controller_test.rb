# frozen_string_literal: true

require 'test_helper'

class BrandFollowsControllerTest < ActionDispatch::IntegrationTest
  test 'index requires sign in' do
    get dashboard_followed_brands_path

    assert_redirected_to new_user_session_path
  end

  test 'index lists the brands the user follows' do
    sign_in users(:one)

    get dashboard_followed_brands_path

    assert_response :success
    assert_select 'h1', text: I18n.t('headings.followed_brands')
    assert_select 'nav .Tabs a[href=?][aria-current="true"]', dashboard_followed_brands_path
    assert_match brands(:one).display_name, @response.body
  end

  test 'index suggests brands from the collection when nothing is followed' do
    user = users(:visible)
    sign_in user

    get dashboard_followed_brands_path

    assert_response :success
    assert_select '.EmptyState', minimum: 1
    assert_match I18n.t('brand_follow.empty_state.no_followed_brands'), @response.body
  end

  test 'create requires sign in' do
    assert_no_difference 'BrandFollow.count' do
      post brand_follows_path, params: { brand_id: brands(:two).id }
    end

    assert_redirected_to new_user_session_path
  end

  test 'create follow' do
    sign_in users(:one)
    brand = brands(:two)

    assert_difference 'BrandFollow.count', 1 do
      post brand_follows_path, params: { brand_id: brand.id }
    end

    assert_redirected_to brand_path(id: brand.friendly_id)
    assert_equal I18n.t('brand_follow.messages.followed', name: brand.display_name), flash[:notice]
    assert users(:one).reload.following_brand?(brand)
  end

  test 'following the same brand twice does not create a second row' do
    sign_in users(:one)
    brand = brands(:one)

    assert_no_difference 'BrandFollow.count' do
      post brand_follows_path, params: { brand_id: brand.id }
    end

    assert_equal I18n.t('brand_follow.messages.followed', name: brand.display_name), flash[:notice]
  end

  test 'create with an unknown brand fails without creating anything' do
    sign_in users(:one)

    assert_no_difference 'BrandFollow.count' do
      post brand_follows_path, params: { brand_id: 0 }
    end

    assert_redirected_to dashboard_root_path
    assert_equal I18n.t(:generic_error_message), flash[:alert]
  end

  test 'destroy unfollows' do
    sign_in users(:one)
    follow = brand_follows(:one_follows_feliks)

    assert_difference 'BrandFollow.count', -1 do
      delete brand_follow_path(follow, redirect_to: dashboard_followed_brands_path)
    end

    assert_redirected_to dashboard_followed_brands_path
  end

  test 'destroy cannot remove another users follow' do
    sign_in users(:one)
    follow = brand_follows(:logged_in_only_follows_feliks)

    assert_no_difference 'BrandFollow.count' do
      delete brand_follow_path(follow)
    end

    assert_redirected_to dashboard_root_path
  end

  test 'an external redirect_to falls back to the brand page' do
    sign_in users(:one)
    brand = brands(:two)

    post brand_follows_path, params: { brand_id: brand.id, redirect_to: 'https://example.com/evil' }

    assert_redirected_to brand_path(id: brand.friendly_id)
  end
end
