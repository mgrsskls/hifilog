# frozen_string_literal: true

require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test 'index' do
    get users_path
    assert_response :success
    assert_select '.Users-ranking table tbody tr', User.count
  end

  test 'index includes users without contributions' do
    get users_path
    assert_response :success

    names = css_select('.Users-ranking table tbody tr td:nth-child(2) b').map { |node| node.text.squish }
    assert_includes names, users(:without_anything).user_name

    scores_by_name = css_select('.Users-ranking table tbody tr').to_h do |row|
      [row.at_css('td:nth-child(2) b').text.squish, row.at_css('td:nth-child(3)').text.to_i]
    end
    assert_equal 0, scores_by_name.fetch(users(:without_anything).user_name)
  end

  test 'index orders users by contribution score descending' do
    low = users(:one)
    mid = users(:visible)
    high = users(:logged_in_only)

    PaperTrail.request(whodunnit: low.id.to_s) do
      products(:one).update!(name: 'Low score contribution')
    end
    PaperTrail.request(whodunnit: mid.id.to_s) do
      products(:one).update!(name: 'Mid score contribution one')
      products(:two).update!(name: 'Mid score contribution two')
    end
    PaperTrail.request(whodunnit: high.id.to_s) do
      products(:one).update!(name: 'High score contribution one')
      products(:two).update!(name: 'High score contribution two')
      products(:diy_kit).update!(name: 'High score contribution three')
    end

    get users_path
    assert_response :success

    names = css_select('.Users-ranking table tbody tr td:nth-child(2) b').map { |node| node.text.squish }
    assert_equal [high.user_name, mid.user_name, low.user_name], names.first(3)

    scores = css_select('.Users-ranking table tbody tr td:nth-child(3)').map { |node| node.text.to_i }
    assert_equal scores.sort.reverse, scores
    assert_equal User.count, names.size
  end

  test 'index shows follow button for followable users when signed in' do
    follower = users(:one)
    followable = users(:logged_in_only)

    get users_path
    assert_response :success
    assert_select '.Users-follow form', count: 0

    sign_in follower
    get users_path
    assert_response :success
    assert_select '.Users-ranking table .Users-follow form',
                  text: /#{Regexp.escape(I18n.t('user_follow.follow'))}/,
                  minimum: 1

    UserFollow.create!(follower: follower, followed: followable)
    get users_path
    assert_response :success
    assert_select '.Users-ranking table .Users-follow form',
                  text: /#{Regexp.escape(I18n.t('user_follow.unfollow'))}/,
                  minimum: 1
  end

  test 'index hides follow button for self, hidden, and blocked users' do
    viewer = users(:one)
    hidden = users(:hidden)
    blocked = users(:logged_in_only)
    followable = users(:with_everything)

    UserBlock.create!(blocker: viewer, blocked: blocked)
    sign_in viewer
    get users_path
    assert_response :success

    follow_forms = css_select('.Users-ranking table .Users-follow form')
    followed_ids = follow_forms.filter_map do |form|
      next if form.at_css('input[name="_method"][value="delete"]')

      Rack::Utils.parse_query(URI(form['action']).query)['followed_id']&.to_i
    end

    assert_includes followed_ids, followable.id
    assert_not_includes followed_ids, viewer.id
    assert_not_includes followed_ids, hidden.id
    assert_not_includes followed_ids, blocked.id
  end

  test 'show' do
    UserActivities::Backfill.run_all

    get user_path(id: 'doesnotexist')
    assert_response :not_found

    get user_path(id: users(:hidden).user_name)
    assert_response :not_found

    get user_path(id: users(:logged_in_only).user_name)
    assert_response :not_found

    get user_path(id: users(:one).user_name)
    assert_response :success
    assert_select 'h2', I18n.t('headings.activity')

    sign_in users(:one)

    get user_path(id: users(:hidden).user_name)
    assert_response :not_found

    get user_path(id: users(:logged_in_only).user_name)
    assert_response :success
    assert_select 'h2', I18n.t('headings.activity')

    get user_path(id: users(:one).user_name)
    assert_response :success
    assert_select 'h2', I18n.t('headings.activity')
  end

  test 'show collection lists six latest possessions with images' do
    user = users(:without_anything)
    sign_in user
    user.possessions.destroy_all

    products = [products(:one), products(:two), products(:diy_kit)]
    8.times do |index|
      travel_to(Time.zone.local(2026, 6, index + 1, 12, 0, 0)) do
        possession = Possession.create!(user: user, product: products[index % products.size], prev_owned: false)
        possession.update!(images: [one_by_one_png_upload(filename: "collection-#{index}.png")])
      end
    end

    get user_path(id: user.user_name)
    assert_response :success
    assert_select '.UserProfile-collection ol li', 6
  end

  test 'show statistics reflect profile owner when logged out' do
    profile_user = users(:one)
    expected_count = profile_user.possessions.where(prev_owned: false).count

    get user_path(id: profile_user.user_name)
    assert_response :success
    assert_select '.UserProfile-statistics .StatisticsNumbers-item:first-child .StatisticsNumber-value',
                  text: expected_count.to_s
  end

  test 'show statistics reflect profile owner when viewing another user' do
    profile_user = users(:one)
    expected_count = profile_user.possessions.where(prev_owned: false).count

    sign_in users(:visible)
    get user_path(id: profile_user.user_name)
    assert_response :success
    assert_select '.UserProfile-statistics .StatisticsNumbers-item:first-child .StatisticsNumber-value',
                  text: expected_count.to_s
    assert_select '.UserProfile-statistics .StatisticsNumbers-item', text: /collection cost/i, count: 0
  end

  test 'show statistics hide collection cost when viewing a profile' do
    profile_user = users(:without_anything)
    Possession.create!(
      user: profile_user,
      product: products(:one),
      prev_owned: false,
      price_purchase: 500,
      price_purchase_currency: 'EUR'
    )

    sign_in users(:visible)
    get user_path(id: profile_user.user_name)
    assert_response :success
    assert_select '.UserProfile-statistics .StatisticsNumbers-item', text: /collection cost/i, count: 0
  end

  test 'collection' do
    get user_collection_path(user_id: 'doesnotexist')
    assert_response :not_found

    get user_collection_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    get user_collection_path(user_id: users(:logged_in_only).user_name)
    assert_response :not_found

    get user_collection_path(user_id: users(:visible).user_name)
    assert_response :success

    sign_in users(:visible)

    get user_collection_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    get user_collection_path(user_id: users(:logged_in_only).user_name)
    assert_response :success

    get user_collection_path(user_id: users(:visible).user_name)
    assert_response :success

    public_setup = users(:one).setups.find_by!(private: false)
    get user_setup_path(user_id: users(:one).user_name, setup: public_setup.friendly_id)
    assert_response :success

    get user_setup_path(user_id: users(:one).user_name, setup: public_setup.id)
    assert_response :redirect
    assert_redirected_to user_setup_path(user_id: users(:one).user_name, setup: public_setup.friendly_id)

    private_setup = users(:one).setups.find_by!(private: true)
    get user_setup_path(user_id: users(:one).user_name, setup: private_setup.friendly_id)
    assert_response :not_found

    get user_collection_path(
      user_id: users(:one).user_name,
      category: users(:one).products.first.sub_categories.first.name.parameterize
    )
    assert_response :success

    get user_setup_path(
      user_id: users(:one).user_name,
      setup: public_setup.friendly_id,
      category: users(:one).products.first.sub_categories.first.name.parameterize
    )
    assert_response :success
  end

  test 'setup collection redirects to canonical slug after rename' do
    user = users(:one)
    user.update!(profile_visibility: :visible)
    setup = user.setups.find_by!(private: false)
    old_slug = setup.slug

    sign_in user
    patch setup_url(setup), params: { setup: { name: 'Renamed public setup' } }
    assert_response :redirect

    setup.reload
    assert_not_equal old_slug, setup.slug

    get user_setup_path(user_id: user.user_name, setup: old_slug)
    assert_response :moved_permanently
    assert_redirected_to user_setup_path(user_id: user.lowercase_user_name, setup: setup.friendly_id)
  end

  test 'contributions' do
    # profile hidden
    get user_contributions_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_contributions_path(user_id: users(:logged_in_only).user_name)
    assert_response :not_found

    # profile visible for logged in and logged out users
    get user_contributions_path(user_id: users(:one).user_name)
    assert_response :success

    sign_in users(:one)

    # profile hidden
    get user_contributions_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_contributions_path(user_id: users(:logged_in_only).user_name)
    assert_response :success

    # profile visible for logged in and logged out users
    get user_contributions_path(user_id: users(:one).user_name)
    assert_response :success
  end

  test 'prev_owneds' do
    # profile hidden
    get user_previous_products_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_previous_products_path(user_id: users(:logged_in_only).user_name)
    assert_response :not_found

    # profile visible for logged in and logged out users
    get user_previous_products_path(user_id: users(:visible).user_name)
    assert_response :success

    sign_in users(:visible)

    # profile hidden
    get user_previous_products_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_previous_products_path(user_id: users(:logged_in_only).user_name)
    assert_response :success

    # profile visible for logged in and logged out users
    get user_previous_products_path(user_id: users(:visible).user_name)
    assert_response :success
  end

  test 'history' do
    # profile hidden
    get user_history_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_history_path(user_id: users(:logged_in_only).user_name)
    assert_response :not_found

    # profile visible for logged in and logged out users
    get user_history_path(user_id: users(:one).user_name)
    assert_response :success

    sign_in users(:one)

    # profile hidden
    get user_history_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_history_path(user_id: users(:logged_in_only).user_name)
    assert_response :success

    # profile visible for logged in and logged out users
    get user_history_path(user_id: users(:one).user_name)
    assert_response :success
  end

  test 'activity redirects to profile' do
    get "/users/#{users(:one).user_name}/activity"
    assert_redirected_to user_path(id: users(:one).user_name.downcase)
    assert_response :moved_permanently
  end

  test 'show follow button when signed in and not own profile' do
    profile_user = users(:logged_in_only)
    sign_in users(:one)

    get user_path(id: profile_user.user_name)
    assert_response :success
    assert_select 'form', text: /#{Regexp.escape(I18n.t('user_follow.follow'))}/

    UserFollow.create!(follower: users(:one), followed: profile_user)
    get user_path(id: profile_user.user_name)
    assert_response :success
    assert_select 'form', text: /#{Regexp.escape(I18n.t('user_follow.unfollow'))}/
  end

  test 'show hides follow button for users the viewer blocked' do
    profile_user = users(:logged_in_only)
    sign_in users(:one)
    UserBlock.create!(blocker: users(:one), blocked: profile_user)

    get user_path(id: profile_user.user_name)
    assert_response :success
    assert_select '.Profile-follow form', count: 0
  end

  test 'show still renders follow button for viewers blocked by the profile owner' do
    profile_user = users(:logged_in_only)
    sign_in users(:one)
    UserBlock.create!(blocker: profile_user, blocked: users(:one))

    get user_path(id: profile_user.user_name)
    assert_response :success
    assert_select '.Profile-follow form', text: /#{Regexp.escape(I18n.t('user_follow.follow'))}/
  end
end
