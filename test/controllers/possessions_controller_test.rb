require 'test_helper'

class PossessionsControllerTest < ActionDispatch::IntegrationTest
  test 'should get previous' do
    get dashboard_prev_owneds_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_prev_owneds_path
    assert_response :success

    get dashboard_prev_owneds_path(category: sub_categories(:one).slug)
    assert_response :success
  end

  test 'should create possession of product' do
    user = users(:one)
    possessions_count = user.possessions.count

    sign_in user

    assert_difference('Possession.count') do
      post possessions_url(id: products(:one).id)
    end
    assert_equal user.possessions.count, possessions_count + 1
    assert_redirected_to product_url(id: Possession.last.product.friendly_id)
  end

  test 'should create possession of product variant' do
    user = users(:one)
    possessions_count = user.possessions.count
    product_variant = product_variants(:three)

    sign_in user

    assert_difference('Possession.count') do
      post possessions_url(
        id: product_variant.product.id,
        product_variant_id: product_variant.id
      )
    end
    assert_equal user.possessions.count, possessions_count + 1
    assert_redirected_to product_variant_url(
      product_id: Possession.last.product.friendly_id,
      id: Possession.last.product_variant.friendly_id
    )
  end

  test 'should create possession of custom product' do
    user = users(:one)
    possessions_count = user.possessions.count

    sign_in user

    assert_difference('Possession.count') do
      post possessions_url(custom_product_id: custom_products(:one).id)
    end
    assert_equal user.possessions.count, possessions_count + 1
    assert_redirected_to user_custom_product_url(
      id: Possession.last.custom_product.id,
      user_id: user.user_name.downcase
    )
  end

  test 'should update possession' do
    user = users(:one)
    possession = user.possessions.first
    setup = user.setups.second
    period_from = '2022-05-15'
    update_path = possession_url(possession)
    update_params = {
      possession: {
        period_from:,
      },
      setup_id: setup.id
    }

    patch update_path, params: update_params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    possession.update!(period_from: nil)
    assert_nil possession.period_from
    assert_nil possession.setup

    patch update_path, params: update_params
    assert_equal user.possessions.find(possession.id).period_from, period_from
    assert_equal user.possessions.find(possession.id).setup, setup
    assert_redirected_to product_url(id: possession.product.friendly_id)
  end

  test 'should destroy current possession' do
    user = users(:one)
    possessions_count = user.possessions.count
    possession = possessions(:current_product)

    delete possession_url(possession)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    product_id = possession.product.friendly_id

    sign_in user

    assert_difference('Possession.count', -1) do
      delete possession_url(possession)
    end
    assert_equal user.possessions.count, possessions_count - 1
    assert_redirected_to product_url(id: product_id)
  end

  test 'should destroy previous possession' do
    user = users(:one)
    possessions_count = user.possessions.count
    possession = possessions(:prev_product)

    delete possession_url(possession)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    product_id = possession.product.friendly_id

    sign_in user

    assert_difference('Possession.count', -1) do
      delete possession_url(possession)
    end
    assert_equal user.possessions.count, possessions_count - 1
    assert_redirected_to product_url(id: product_id)
  end

  test 'move product to previous possessions' do
    user = users(:one)
    possession = possessions(:current_product)

    post possession_move_to_prev_owneds_url(possession)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    assert_equal possession.prev_owned, false

    sign_in user

    post possession_move_to_prev_owneds_url(possession)
    assert_equal Possession.find(possession.id).prev_owned, true
    assert_redirected_to product_url(id: possession.product.friendly_id)
  end

  test 'move product variant to previous possessions' do
    user = users(:one)
    possession = possessions(:current_product_variant)

    post possession_move_to_prev_owneds_url(possession)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    assert_equal possession.prev_owned, false

    sign_in user

    post possession_move_to_prev_owneds_url(possession)
    assert_equal Possession.find(possession.id).prev_owned, true
    assert_redirected_to product_variant_url(
      id: possession.product_variant.friendly_id,
      product_id: possession.product_variant.product.friendly_id
    )
  end

  test 'move custom product to previous possessions' do
    user = users(:one)
    possession = possessions(:current_custom_product)

    post possession_move_to_prev_owneds_url(possession)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    assert_equal possession.prev_owned, false

    sign_in user

    post possession_move_to_prev_owneds_url(possession)
    assert_equal Possession.find(possession.id).prev_owned, true
    assert_redirected_to user_custom_product_url(id: possession.custom_product.id, user_id: user.user_name.downcase)
  end
end
