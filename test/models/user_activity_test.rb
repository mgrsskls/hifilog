# frozen_string_literal: true

require 'test_helper'

class UserActivityTest < ActiveSupport::TestCase
  test 'accepts setup product verbs' do
    activity = UserActivity.new(
      user: users(:one),
      subject: setups(:one),
      verb: 'setup_product_added',
      occurred_at: Time.current,
      metadata: {}
    )
    assert activity.valid?
  end

  test 'accepts setup_made_private verb' do
    activity = UserActivity.new(
      user: users(:one),
      subject: setups(:one),
      verb: 'setup_made_private',
      occurred_at: Time.current,
      metadata: {}
    )
    assert activity.valid?
  end

  test 'rejects unknown verb' do
    activity = UserActivity.new(
      user: users(:one),
      subject: possessions(:current_product),
      verb: 'not_a_real_verb',
      occurred_at: Time.current,
      metadata: {}
    )
    assert_not activity.valid?
    assert activity.errors[:verb].present?
  end

  test 'accepts known verb' do
    activity = UserActivity.new(
      user: users(:one),
      subject: possessions(:current_product),
      verb: 'added_to_collection',
      occurred_at: Time.current,
      metadata: {}
    )
    assert activity.valid?
  end

  test 'requires occurred_at' do
    activity = UserActivity.new(
      user: users(:one),
      subject: possessions(:current_product),
      verb: 'added_to_collection',
      metadata: {}
    )
    assert_not activity.valid?
    assert activity.errors[:occurred_at].present?
  end

  test 'verb_sym' do
    activity = UserActivity.new(verb: 'setup_created')
    assert_equal :setup_created, activity.verb_sym
  end

  test 'for_public_profile_feed scope excludes private feed verbs' do
    user = users(:one)
    follow = user_follows(:visible_follows_one)
    UserActivities::Recorder.followed_by_user(follow)

    assert_includes user.user_activities.visible.for_feed.pluck(:verb), 'followed_by_user'
    assert_not_includes user.user_activities.visible.for_public_profile_feed.pluck(:verb), 'followed_by_user'
  end

  test 'for_feed scope excludes feed-hidden verbs' do
    user = users(:without_anything)
    possession = Possession.create!(user: user, product: products(:one), prev_owned: false)
    possession.update!(images: [one_by_one_png_upload(filename: 'scope.png')])
    attachment = possession.images.attachments.sole

    UserActivity.where(user: user, subject: possession, verb: 'possession_image_uploaded').delete_all
    UserActivities::Recorder.possession_image_uploaded(possession, image_attachment: attachment)

    assert UserActivity.exists?(user: user, verb: 'possession_image_uploaded')
    assert_includes user.user_activities.visible.for_feed.pluck(:verb), 'possession_image_uploaded'

    user.update!(avatar: one_by_one_png_upload(filename: 'scope-avatar.png'))
    UserActivities::Recorder.avatar_uploaded(user, image_attachment: user.avatar.attachment)
    assert_not_includes user.user_activities.visible.for_feed.pluck(:verb), 'avatar_uploaded'
    assert_includes user.user_activities.visible.pluck(:verb), 'avatar_uploaded'
  end

  test 'visible scope excludes hidden' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 1, 5, 12, 0, 0)) do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
    end
    UserActivities::Recorder.sync_possession(possession)
    act = UserActivity.find_by!(user: user, subject: possession, verb: 'added_to_collection')

    assert_includes UserActivity.visible.pluck(:id), act.id

    act.update!(hidden_at: Time.zone.local(2026, 1, 6, 12, 0, 0))
    assert_not_includes UserActivity.visible.pluck(:id), act.id
  end
end
