require 'test_helper'

class NotesControllerTest < ActionDispatch::IntegrationTest
  test 'index without notes' do
    user = users(:one)

    get dashboard_notes_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user
    user.notes.destroy_all
    assert_equal user.notes.count, 0

    get dashboard_notes_url
    assert_response :success
  end

  test 'index with notes' do
    user = users(:one)

    get dashboard_notes_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user
    assert_equal user.notes.count, 1

    get dashboard_notes_url
    assert_response :success
  end

  test 'should get new for product' do
    get product_new_notes_url(product_id: products(:one).friendly_id)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get product_new_notes_url(product_id: products(:one).friendly_id)
    assert_response :success
  end

  test 'should get new for product variant' do
    product_variant = product_variants(:one)

    get product_new_variant_notes_url(
      product_id: product_variant.product.friendly_id,
      id: product_variant.friendly_id
    )
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get product_new_variant_notes_url(
      product_id: product_variant.product.friendly_id,
      id: product_variant.friendly_id
    )
    assert_response :success
  end

  test 'should create note for product' do
    user = users(:one)
    product = products(:two)
    notes_count = user.notes.count

    post notes_url, params: { note: {
      text: 'text',
      product_id: product.id,
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    assert_difference('Note.count') do
      post notes_url, params: { note: {
        text: 'text',
        product_id: product.id,
      } }
    end
    assert_equal user.notes.count, notes_count + 1
    assert_redirected_to product_new_notes_url(product_id: product.friendly_id)
  end

  test 'should create note for product variant' do
    user = users(:one)
    product_variant = product_variants(:two)
    product = product_variant.product
    notes_count = user.notes.count

    post notes_url, params: { note: {
      text: 'text',
      product_id: product.id,
      product_variant_id: product_variant.id,
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    assert_difference('Note.count') do
      post notes_url, params: { note: {
        text: 'text',
        product_id: product.id,
        product_variant_id: product_variant.id,
      } }
    end
    assert_equal user.notes.count, notes_count + 1
    assert_redirected_to product_new_variant_notes_url(
      product_id: product.friendly_id,
      id: product_variant.friendly_id
    )
  end

  test 'should show note of product' do
    user = users(:one)
    note = user.notes.first

    get dashboard_note_url(note)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    get dashboard_note_url(note)
    assert_response :success
  end

  test 'should show note of product variant' do
    user = users(:one)
    note = user.notes.first

    note.update!(product_variant_id: product_variants(:one).id)

    get dashboard_note_url(note)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    get dashboard_note_url(note)
    assert_response :success
  end

  test 'should update note' do
    user = users(:one)
    note = user.notes.first
    new_text = 'New text'

    patch note_url(note), params: { note: {
      text: new_text
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    patch note_url(note), params: { note: {
      text: new_text
    } }
    assert_redirected_to product_new_notes_url(product_id: note.product.friendly_id)
  end

  test 'should destroy note' do
    user = users(:one)
    note = user.notes.first
    notes_count = user.notes.count

    sign_in user

    assert_difference('Note.count', -1) do
      delete note_url(note)
    end
    assert_equal user.notes.count, notes_count - 1
    assert_redirected_to dashboard_notes_url
  end
end
