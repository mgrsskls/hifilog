require 'test_helper'

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @note = notes(:one)
  end

  test 'should get index' do
    get dashboard_notes_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    get dashboard_notes_url
    assert_response :success
  end

  test 'should get new' do
    get product_new_notes_path(product_id: products(:one).friendly_id)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    get product_new_notes_path(product_id: products(:one).friendly_id)
    assert_response :success
  end

  test 'should create note' do
    post notes_url, params: { note: {
      text: 'text',
      product_id: products(:one).id
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    assert_difference('Note.count') do
      post notes_url, params: { note: {
        text: 'text',
        product_id: products(:with_variants).id,
      } }
    end

    assert_redirected_to product_new_notes_url(product_id: products(:with_variants).friendly_id)
  end

  test 'should show note' do
    get dashboard_note_url(@note)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    get dashboard_note_url(@note)
    assert_response :success
  end

  test 'should update note' do
    patch note_url(@note), params: { note: {
      text: 'text'
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    patch note_url(@note), params: { note: {
      text: 'text'
    } }
    assert_redirected_to product_new_notes_url(product_id: @note.product.friendly_id)
  end

  test 'should destroy note' do
    sign_in users(:with_everything)

    assert_difference('Note.count', -1) do
      delete note_url(@note)
    end

    assert_redirected_to dashboard_notes_url
  end
end
