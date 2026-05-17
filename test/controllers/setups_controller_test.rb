# frozen_string_literal: true

require 'test_helper'

class SetupsControllerTest < ActionDispatch::IntegrationTest
  test 'index' do
    get dashboard_setups_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:visible)

    get dashboard_setups_path
    assert_response :success
  end

  test 'show' do
    setup = setups(:with_products)

    get dashboard_setup_path(setup)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:without_anything)
    get dashboard_setup_path(setup)
    assert_response :not_found

    sign_out users(:without_anything)

    sign_in users(:with_everything)

    get dashboard_setup_path(setup)
    assert_response :success

    get dashboard_setup_path(
      setup,
      category: setup.possessions.where.not(product_id: nil).first.product.sub_categories.first.slug
    )
    assert_response :success

    get dashboard_setup_path(setups(:without_products))
    assert_response :success
  end

  test 'new' do
    get new_dashboard_setup_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get new_dashboard_setup_url
    assert_response :success
  end

  test 'edit' do
    user = users(:one)
    setup = user.setups.first

    get edit_dashboard_setup_url(setup)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    get edit_dashboard_setup_url(setup)
    assert_response :success
  end

  test 'create' do
    user = users(:one)
    params = {
      setup: {
        name: 'name',
        private: false
      }
    }

    post setups_url, params: params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    post setups_url, params: params
    assert_response :redirect
    assert_redirected_to dashboard_setups_path
  end

  test 'update' do
    user = users(:one)
    setup = user.setups.first
    params = {
      setup: {
        private: true
      }
    }

    patch setup_url(id: setup.id), params: params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    patch setup_url(id: setup.id), params: params
    assert_response :redirect
    assert_redirected_to dashboard_setups_path
  end

  test 'update name only preserves possessions' do
    user = users(:with_everything)
    setup = setups(:with_products)
    possession_count = setup.possessions.count
    assert possession_count.positive?

    sign_in user

    patch setup_url(setup), params: { setup: { name: 'Renamed only', private: setup.private } }

    assert_response :redirect
    setup.reload
    assert_equal 'Renamed only', setup.name
    assert_equal possession_count, setup.possessions.count
  end

  test 'update changes slug when name changes' do
    user = users(:one)
    setup = user.setups.first
    old_slug = setup.slug

    sign_in user

    patch setup_url(setup), params: { setup: { name: 'Renamed setup' } }
    assert_response :redirect

    setup.reload
    assert_equal 'Renamed setup', setup.name
    assert_equal 'renamed-setup', setup.slug
    assert_not_equal old_slug, setup.slug
  end

  test 'update with possession_ids syncs setup possessions' do
    user = users(:one)
    setup = setups(:one)
    possession = Possession.create!(user:, product: products(:two), prev_owned: false)
    other = Possession.create!(user:, product: products(:diy_kit), prev_owned: false)
    SetupPossession.create!(setup:, possession:)
    SetupPossession.create!(setup:, possession: other)

    sign_in user

    patch setup_url(setup), params: {
      setup: {
        possession_ids: ['', possession.id]
      }
    }

    assert_response :redirect
    setup.reload
    assert_equal [possession.id], setup.possession_ids
  end

  test 'update with empty possession_ids clears setup possessions' do
    user = users(:one)
    setup = setups(:one)
    possession = Possession.create!(user:, product: products(:two), prev_owned: false)
    SetupPossession.create!(setup:, possession:)

    sign_in user

    patch setup_url(setup), params: {
      setup: {
        possession_ids: ['']
      }
    }

    assert_response :redirect
    assert_empty setup.reload.possession_ids
  end

  test 'update ignores possession_ids from other users' do
    attacker = users(:one)
    victim = users(:visible)
    victim_possession = Possession.create!(user: victim, product: products(:two), prev_owned: false)
    setup = attacker.setups.first

    sign_in attacker

    patch setup_url(id: setup.id), params: {
      setup: {
        possession_ids: [victim_possession.id]
      }
    }

    assert_response :redirect
    assert_not_includes setup.reload.possession_ids, victim_possession.id
    assert_nil victim_possession.reload.setup
  end

  test 'destroy' do
    user = users(:one)
    setup = user.setups.first
    setups_count = user.setups.count

    delete setup_path(setup)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    delete setup_path(setup)

    assert_equal setups_count - 1, user.setups.count
    assert_response :redirect
    assert_redirected_to dashboard_setups_url
  end
end
