# frozen_string_literal: true

require 'test_helper'

class UserActivitiesRecorderTest < ActiveSupport::TestCase
  test 'sync_possession hides stale verb rows when possession state changes' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 3, 3, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:diy_kit), prev_owned: true)
    end
    UserActivities::Recorder.sync_possession(possession)
    assert UserActivity.visible.exists?(user: user, subject: possession, verb: 'added_to_previous')

    possession.update!(prev_owned: false, moved_to_previous_at: nil)
    UserActivities::Recorder.sync_possession(possession.reload)

    assert UserActivity.visible.exists?(user: user, subject: possession, verb: 'added_to_collection')
    stale = UserActivity.find_by!(user: user, subject: possession, verb: 'added_to_previous')
    assert stale.hidden_at.present?
  end

  test 'sync_possession is idempotent for same possession state' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 3, 1, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
    end

    UserActivities::Recorder.sync_possession(possession)
    count_after_first = UserActivity.where(user: user, subject: possession).count

    UserActivities::Recorder.sync_possession(possession.reload)
    assert_equal count_after_first, UserActivity.where(user: user, subject: possession).count
  end

  test 'hide_possession_activities! sets hidden_at on all possession activities' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 3, 2, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:two), prev_owned: false)
    end
    possession.update!(prev_owned: true)
    UserActivities::Recorder.sync_possession(possession.reload)

    acts = UserActivity.where(user: user, subject: possession)
    assert acts.any?
    assert(acts.all? { |a| a.hidden_at.nil? })

    UserActivities::Recorder.hide_possession_activities!(possession)
    assert(UserActivity.where(user: user, subject: possession).all? { |a| a.reload.hidden_at.present? })
  end

  test 'setup_made_public creates a distinct activity row' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 4, 1, 9, 0, 0)) do
      Setup.create!(user: user, name: 'Recorder private setup', private: true)
    end
    assert UserActivity.exists?(user: user, subject: setup, verb: 'setup_created')

    assert_difference(-> { UserActivity.where(user: user, subject: setup).count }, 1) do
      travel_to(Time.zone.local(2026, 4, 1, 10, 0, 0)) do
        setup.update!(private: false)
      end
    end

    verbs = UserActivity.where(user: user, subject: setup).order(:occurred_at).pluck(:verb)
    assert_includes verbs, 'setup_created'
    assert_includes verbs, 'setup_made_public'
  end

  test 'setup_made_private creates a distinct activity row when setup becomes private' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 4, 2, 9, 0, 0)) do
      Setup.create!(user: user, name: 'Recorder public then private', private: false)
    end

    assert_difference(-> { UserActivity.where(user: user, subject: setup, verb: 'setup_made_private').count }, 1) do
      travel_to(Time.zone.local(2026, 4, 2, 10, 0, 0)) do
        setup.update!(private: true)
      end
    end
  end

  test 'event_attendance_cancelled creates activity with event subject' do
    user = users(:without_anything)
    event = travel_to(Time.zone.local(2026, 5, 1, 12, 0, 0)) do
      Event.create!(
        name: 'Cancelled event',
        address: 'a',
        url: 'https://example.test/cancel-rec',
        country_code: 'DE',
        start_date: Date.new(2026, 6, 1),
        end_date: Date.new(2026, 6, 2)
      )
    end

    assert_difference(-> { UserActivity.where(user: user, verb: 'event_attendance_cancelled').count }, 1) do
      UserActivities::Recorder.event_attendance_cancelled(user: user, event: event)
    end

    act = UserActivity.find_by!(user: user, subject: event, verb: 'event_attendance_cancelled')
    assert_equal 'Cancelled event', act.metadata['display_name']
  end

  test 'possession_image_deleted creates activity with possession subject' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 7, 2, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:two), prev_owned: false)
    end
    possession.update!(images: [one_by_one_png_upload(filename: 'delete-me.png')])
    attachment = possession.images.attachments.sole

    assert_difference(lambda {
      UserActivity.where(user: user, subject: possession, verb: 'possession_image_deleted').count
    }, 1) do
      travel_to(Time.zone.local(2026, 7, 2, 11, 0, 0)) do
        UserActivities::Recorder.possession_image_deleted(possession, image_attachment: attachment)
      end
    end

    act = UserActivity.find_by!(user: user, subject: possession, verb: 'possession_image_deleted')
    assert_equal Time.zone.local(2026, 7, 2, 11, 0, 0), act.occurred_at
    assert_equal attachment.id, act.metadata['image_attachment_id'].to_i
  end

  test 'possession_image_deleted skips without image attachment id' do
    user = users(:without_anything)
    possession = Possession.create!(user: user, product: products(:two), prev_owned: false)

    assert_no_difference(-> { UserActivity.where(verb: 'possession_image_deleted', subject: possession).count }) do
      UserActivities::Recorder.possession_image_deleted(possession)
    end
  end

  test 'possession_image_uploaded creates activity with possession subject' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 7, 1, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
    end
    possession.update!(images: [one_by_one_png_upload(filename: 'upload.png')])
    attachment = possession.images.attachments.sole
    UserActivity.where(user: user, subject: possession, verb: 'possession_image_uploaded').delete_all

    assert_difference(lambda {
      UserActivity.where(user: user, subject: possession, verb: 'possession_image_uploaded').count
    }, 1) do
      travel_to(Time.zone.local(2026, 7, 1, 11, 0, 0)) do
        UserActivities::Recorder.possession_image_uploaded(possession, image_attachment: attachment)
      end
    end

    act = UserActivity.find_by!(user: user, subject: possession, verb: 'possession_image_uploaded')
    assert_equal Time.zone.local(2026, 7, 1, 11, 0, 0), act.occurred_at
    assert act.metadata['display_name'].present?
    assert_equal attachment.id, act.metadata['image_attachment_id'].to_i
  end

  test 'possession_image_uploaded is idempotent per attachment id' do
    user = users(:without_anything)
    possession = Possession.create!(user: user, product: products(:one), prev_owned: false)
    possession.update!(images: [one_by_one_png_upload(filename: 'dup.png')])
    attachment = possession.images.attachments.sole
    UserActivity.where(user: user, subject: possession, verb: 'possession_image_uploaded').delete_all

    assert_difference(-> { UserActivity.where(verb: 'possession_image_uploaded', subject: possession).count }, 1) do
      UserActivities::Recorder.possession_image_uploaded(possession, image_attachment: attachment)
      UserActivities::Recorder.possession_image_uploaded(possession, image_attachment: attachment)
    end
  end

  test 'avatar_deleted creates activity with user subject' do
    user = users(:without_anything)
    user.update!(avatar: one_by_one_png_upload(filename: 'delete-me.png'))
    attachment = user.avatar.attachment

    assert_difference(-> { UserActivity.where(user: user, subject: user, verb: 'avatar_deleted').count }, 1) do
      travel_to(Time.zone.local(2026, 7, 3, 11, 0, 0)) do
        UserActivities::Recorder.avatar_deleted(user, image_attachment: attachment)
      end
    end

    act = UserActivity.find_by!(user: user, subject: user, verb: 'avatar_deleted')
    assert_equal Time.zone.local(2026, 7, 3, 11, 0, 0), act.occurred_at
    assert_equal attachment.id, act.metadata['image_attachment_id'].to_i
  end

  test 'avatar_uploaded is idempotent per attachment id' do
    user = users(:without_anything)
    user.update!(avatar: one_by_one_png_upload(filename: 'dup.png'))
    attachment = user.avatar.attachment
    UserActivity.where(user: user, subject: user, verb: 'avatar_uploaded').delete_all

    assert_difference(-> { UserActivity.where(verb: 'avatar_uploaded', subject: user).count }, 1) do
      UserActivities::Recorder.avatar_uploaded(user, image_attachment: attachment)
      UserActivities::Recorder.avatar_uploaded(user, image_attachment: attachment)
    end
  end

  test 'decorative_image_uploaded creates activity with user subject' do
    user = users(:without_anything)
    user.update!(decorative_image: one_by_one_png_upload(filename: 'banner.png'))
    attachment = user.decorative_image.attachment
    UserActivity.where(user: user, subject: user, verb: 'decorative_image_uploaded').delete_all

    assert_difference(-> { UserActivity.where(verb: 'decorative_image_uploaded', subject: user).count }, 1) do
      UserActivities::Recorder.decorative_image_uploaded(user, image_attachment: attachment)
    end

    act = UserActivity.find_by!(user: user, subject: user, verb: 'decorative_image_uploaded')
    assert_equal user.user_name, act.metadata['display_name']
    assert_equal attachment.id, act.metadata['image_attachment_id'].to_i
  end

  test 'custom_product_created skips when user missing' do
    cp = CustomProduct.new(name: 'orphan')

    assert_no_difference(-> { UserActivity.count }) do
      UserActivities::Recorder.custom_product_created(cp)
    end
  end

  test 'followed_by_user records activity for followed user' do
    follower = users(:one)
    followed = users(:without_anything)
    follow = UserFollow.create!(follower:, followed:)

    act = UserActivity.find_by!(user: followed, subject: follow, verb: 'followed_by_user')
    assert_equal follower.user_name, act.metadata['follower_user_name']
    assert_equal follower.profile_path, act.metadata['url']
  end

  test 'hide_followed_by_user hides activity on unfollow' do
    follow = user_follows(:one_follows_visible)
    # Fixtures bypass the after_commit callback that records the activity.
    UserActivities::Recorder.followed_by_user(follow)
    act = UserActivity.find_by!(user: follow.followed, subject: follow, verb: 'followed_by_user')

    follow.destroy

    assert act.reload.hidden_at.present?
  end
end
