# frozen_string_literal: true

require 'test_helper'

# The name input in the import candidate table saves on its own, without a form.
class AdminImportCandidateRenameTest < ActionDispatch::IntegrationTest
  setup do
    @candidate = ImportCandidate.create!(
      brand: brands(:one), brand_slug: brands(:one).slug, name: 'Euforia',
      source_url: 'https://feliksaudio.pl/products/euforia'
    )
  end

  test 'an admin renames a candidate, and the row is marked as edited' do
    sign_in admin_users(:admin_user)

    patch rename_admin_import_candidate_path(@candidate), params: { name: '  Euforia Evolution ' }, as: :json

    assert_response :success
    assert_equal 'Euforia Evolution', response.parsed_body['value']
    @candidate.reload
    assert_equal 'Euforia Evolution', @candidate.name
    assert_predicate @candidate, :edited?
    assert_equal admin_users(:admin_user), @candidate.edited_by
  end

  test 'an empty name is refused and nothing changes' do
    sign_in admin_users(:admin_user)

    patch rename_admin_import_candidate_path(@candidate), params: { name: ' ' }, as: :json

    assert_response :unprocessable_content
    assert_predicate response.parsed_body['error'], :present?
    assert_equal 'Euforia', @candidate.reload.name
    assert_not_predicate @candidate, :edited?
  end

  test 'the index shows the candidates as a grid of cards' do
    sign_in admin_users(:admin_user)

    get admin_import_candidates_path

    assert_response :success
    assert_select format('article#grid_item_%d', @candidate.id) do
      assert_select 'input[data-inline-edit-url=?][value=?]', rename_admin_import_candidate_path(@candidate), 'Euforia'
      assert_select 'input.batch-actions-resource-selection[value=?]', @candidate.id.to_s
    end
  end

  test 'publish writes the product at once and marks the candidate as imported' do
    sign_in admin_users(:admin_user)
    @candidate.update!(sub_category_ids: [sub_categories(:one).id], model_no: 'EUF-PUB-1')

    assert_difference -> { Product.count }, 1 do
      post publish_admin_import_candidate_path(@candidate)
    end

    @candidate.reload
    assert_predicate @candidate, :imported?
    assert_equal admin_users(:admin_user), @candidate.reviewed_by
    assert_equal 'Euforia', @candidate.product.name
  end

  test 'a candidate that cannot be published keeps its status' do
    sign_in admin_users(:admin_user)

    assert_no_difference -> { Product.count } do
      post publish_admin_import_candidate_path(@candidate)
    end

    assert_predicate @candidate.reload, :pending?
    assert_match 'no sub category', flash[:alert]
  end

  test 'a visitor cannot rename a candidate' do
    patch rename_admin_import_candidate_path(@candidate), params: { name: 'Other' }, as: :json

    assert_equal 'Euforia', @candidate.reload.name
  end
end
