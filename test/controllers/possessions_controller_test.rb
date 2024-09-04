require 'test_helper'

class PossessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @possession = possessions(:without_variant)
  end

  test 'should get index' do
    get possessions_url
    assert_response :not_found
  end

  test 'should create possession' do
    sign_in users(:with_everything)

    assert_difference('Possession.count') do
      post possessions_url(id: products(:one).id), params: { possession: {} }
    end

    assert_redirected_to product_url(id: Possession.last.product.friendly_id)
  end

  test 'should show possession' do
    get possession_url(@possession)
    assert_response :not_found
  end

  test 'should update possession' do
    patch possession_url(@possession), params: { possession: {
      setup_id: users(:with_everything).setups.first.id
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    patch possession_url(@possession), params: { possession: {
      setup_id: users(:with_everything).setups.first.id
    } }
    assert_redirected_to product_url(id: @possession.product.friendly_id)
  end

  test 'should destroy possession' do
    delete possession_url(@possession)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    product_id = @possession.product.friendly_id

    sign_in users(:with_everything)

    assert_difference('Possession.count', -1) do
      delete possession_url(@possession)
    end

    assert_redirected_to product_url(id: product_id)
  end
end
