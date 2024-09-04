require 'test_helper'

class SetupPossessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @setup_possession = setup_possessions(:one)
  end

  test 'should destroy setup_possession' do
    product_id = @setup_possession.possession.product.friendly_id
    delete setup_possession_url(@setup_possession)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    assert_difference('SetupPossession.count', -1) do
      delete setup_possession_url(@setup_possession)
    end

    assert_redirected_to product_url(id: product_id)
  end
end
