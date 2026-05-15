# frozen_string_literal: true

require 'test_helper'

class PossessionTest < ActiveSupport::TestCase
  test 'brand delegation for product' do
    possession = possessions(:current_product)
    assert_equal possession.product.brand, possession.brand
  end

  test 'brand delegation for product variant' do
    possession = possessions(:current_product_variant)
    assert_equal possession.product_variant.product.brand, possession.brand
  end

  test 'brand for custom product' do
    possession = possessions(:current_custom_product)
    assert_nil possession.brand
  end

  test 'duration for current possession' do
    possession = possessions(:current_product)
    possession.update!(period_from: 30.days.ago)
    duration = possession.duration
    assert duration > 28 * 86_400 # More than 28 days in seconds
    assert duration < 31 * 86_400 # Less than 31 days in seconds
  end

  test 'duration for previous possession' do
    possession = possessions(:prev_product)
    assert_nil possession.duration if possession.period_to.blank?

    # Freeze time at the start of a specific second
    # otherwise, the duration may be off by a few seconds due to the time taken to execute the code
    travel_to Time.zone.local(2026, 3, 28, 12, 0, 0) do
      possession.update!(period_from: 100.days.ago, period_to: 50.days.ago)

      duration = possession.duration
      assert_equal 50.days.to_i, duration
    end
  end

  test 'purchase_condition is optional' do
    possession = possessions(:current_product)
    assert_nil possession.purchase_condition
    possession.update!(purchase_condition: :second_hand)
    assert possession.second_hand?
    possession.update!(purchase_condition: nil)
    assert_nil possession.reload.purchase_condition
  end

  test 'purchase_condition enum values' do
    possession = possessions(:current_product)
    possession.update!(purchase_condition: :first_hand)
    assert possession.first_hand?
    possession.update!(purchase_condition: :b_stock)
    assert possession.b_stock?
  end

  test 'purchase_condition_label' do
    possession = possessions(:current_product)
    assert_nil possession.purchase_condition_label

    possession.purchase_condition = :first_hand
    assert_equal 'New (first-hand)', possession.purchase_condition_label

    possession.purchase_condition = :second_hand
    assert_equal 'Second-hand', possession.purchase_condition_label

    possession.purchase_condition = :b_stock
    assert_equal 'B-stock', possession.purchase_condition_label
  end

  test 'stamps moved_to_previous_at when prev_owned flips to true on update' do
    user = users(:without_anything)
    travel_to(Time.zone.local(2026, 6, 10, 14, 30, 0)) do
      possession = Possession.create!(user: user, product: products(:one), prev_owned: false)
      assert_nil possession.moved_to_previous_at

      possession.update!(prev_owned: true)

      assert possession.reload.moved_to_previous_at.present?
      assert possession.prev_owned?
    end
  end

  test 'does not stamp moved_to_previous_at when created already previous' do
    user = users(:without_anything)
    possession = Possession.create!(user: user, product: products(:two), prev_owned: true)

    assert_nil possession.reload.moved_to_previous_at
  end

  test 'attaching images records possession_image_uploaded activities' do
    possession = possessions(:current_product)
    possession.images.purge if possession.images.attached?

    assert_difference(-> { UserActivity.where(verb: 'possession_image_uploaded', subject: possession).count }, 1) do
      possession.update!(images: [one_by_one_png_upload(filename: 'one.png')])
    end

    attachment_id = possession.images.attachments.sole.id
    act = UserActivity.find_by!(
      user: possession.user,
      subject: possession,
      verb: 'possession_image_uploaded',
      hidden_at: nil
    )
    assert_equal attachment_id, act.metadata['image_attachment_id'].to_i
  end

  test 'attaching multiple images records one activity per new image' do
    possession = possessions(:current_product)
    possession.images.purge if possession.images.attached?
    assert_difference(-> { UserActivity.where(verb: 'possession_image_uploaded', subject: possession).count }, 2) do
      possession.update!(
        images: [
          one_by_one_png_upload(filename: 'one.png'),
          one_by_one_png_upload(filename: 'two.png')
        ]
      )
    end

    attachment_ids = possession.images.attachments.map(&:id)
    recorded_ids = UserActivity.where(verb: 'possession_image_uploaded', subject: possession)
                               .pluck(Arel.sql("metadata->>'image_attachment_id'"))
                               .map(&:to_i)
    assert_equal attachment_ids.sort, recorded_ids.sort
  end

  test 'purging images records possession_image_deleted activities' do
    possession = possessions(:current_product)
    possession.images.purge if possession.images.attached?
    possession.update!(images: [one_by_one_png_upload(filename: 'one.png')])
    attachment_id = possession.images.attachments.sole.id

    assert_difference(-> { UserActivity.where(verb: 'possession_image_deleted', subject: possession).count }, 1) do
      possession.purge_images_by_id!([attachment_id])
    end

    act = UserActivity.find_by!(
      user: possession.user,
      subject: possession,
      verb: 'possession_image_deleted',
      hidden_at: nil
    )
    assert_equal attachment_id, act.metadata['image_attachment_id'].to_i
    assert_not possession.reload.images.attached?
  end

  test 're-attaching same possession does not duplicate upload activities for existing attachments' do
    possession = possessions(:current_product)
    possession.images.purge if possession.images.attached?
    possession.update!(images: [one_by_one_png_upload(filename: 'one.png')])
    attachment_id = possession.images.attachments.sole.id

    assert_no_difference(-> { UserActivity.where(verb: 'possession_image_uploaded', subject: possession).count }) do
      UserActivities::Recorder.possession_image_uploaded(
        possession,
        image_attachment: possession.images.attachments.sole
      )
    end

    assert_equal 1, UserActivity.where(
      verb: 'possession_image_uploaded',
      subject: possession
    ).where("metadata->>'image_attachment_id' = ?", attachment_id.to_s).count
  end

  test 'updating possession without new images does not record image upload activities' do
    possession = possessions(:current_product)
    possession.images.purge if possession.images.attached?
    possession.update!(images: [one_by_one_png_upload(filename: 'one.png')])
    UserActivity.where(verb: 'possession_image_uploaded', subject: possession).delete_all

    assert_no_difference(-> { UserActivity.where(verb: 'possession_image_uploaded', subject: possession).count }) do
      possession.update!(period_from: 1.day.ago)
    end
  end

  test 'destroy sets hidden_at on related user activities' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 8, 1, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:diy_kit), prev_owned: false)
    end
    UserActivities::Recorder.sync_possession(possession)
    assert UserActivity.exists?(user: user, subject: possession, hidden_at: nil)

    possession.destroy!

    assert UserActivity.where(user: user, subject_id: possession.id, subject_type: 'Possession').all? do |a|
      a.reload.hidden_at.present?
    end
  end
end
