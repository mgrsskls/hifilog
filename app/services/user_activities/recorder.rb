# frozen_string_literal: true

class UserActivities::Recorder
  class << self
    def sync_possession(possession)
      user_id = possession.user_id
      return unless user_id

      expected = UserActivities::PossessionSync.expected_rows(possession)
      expected_verbs = expected.map { |row| row[:verb].to_s }

      expected.each do |row|
        upsert_activity!(
          user_id:,
          subject: possession,
          verb: row[:verb].to_s,
          occurred_at: row[:occurred_at],
          metadata: row[:metadata] || {}
        )
      end

      hide_stale_possession_activities!(possession, expected_verbs)
    end

    def hide_possession_activities!(possession)
      UserActivity.where(subject: possession).find_each do |activity|
        activity.update!(hidden_at: Time.current)
      end
    end

    def possession_image_uploaded(possession, occurred_at: Time.current, image_attachment: nil,
                                  image_attachment_id: nil, presenter: nil)
      record_possession_image_activity!(
        possession,
        verb: 'possession_image_uploaded',
        occurred_at:,
        attachment: image_attachment || image_attachment_id,
        presenter:
      )
    end

    def possession_image_deleted(possession, occurred_at: Time.current, image_attachment: nil, image_attachment_id: nil,
                                 presenter: nil)
      record_possession_image_activity!(
        possession,
        verb: 'possession_image_deleted',
        occurred_at:,
        attachment: image_attachment || image_attachment_id,
        presenter:
      )
    end

    def possession_image_activity_exists?(user_id:, possession:, verb:, image_attachment_id:)
      return false if image_attachment_id.blank?

      UserActivity.where(user_id:, subject: possession, verb:)
                  .exists?(["metadata->>'image_attachment_id' = ?", image_attachment_id.to_s])
    end

    def avatar_uploaded(user, occurred_at: Time.current, image_attachment: nil, image_attachment_id: nil)
      record_user_profile_image_activity!(
        user,
        verb: 'avatar_uploaded',
        occurred_at:,
        attachment: image_attachment || image_attachment_id
      )
    end

    def avatar_deleted(user, occurred_at: Time.current, image_attachment: nil, image_attachment_id: nil)
      record_user_profile_image_activity!(
        user,
        verb: 'avatar_deleted',
        occurred_at:,
        attachment: image_attachment || image_attachment_id
      )
    end

    def decorative_image_uploaded(user, occurred_at: Time.current, image_attachment: nil, image_attachment_id: nil)
      record_user_profile_image_activity!(
        user,
        verb: 'decorative_image_uploaded',
        occurred_at:,
        attachment: image_attachment || image_attachment_id
      )
    end

    def decorative_image_deleted(user, occurred_at: Time.current, image_attachment: nil, image_attachment_id: nil)
      record_user_profile_image_activity!(
        user,
        verb: 'decorative_image_deleted',
        occurred_at:,
        attachment: image_attachment || image_attachment_id
      )
    end

    def user_profile_image_activity_exists?(user_id:, user:, verb:, image_attachment_id:)
      return false if image_attachment_id.blank?

      UserActivity.where(user_id:, subject: user, verb:)
                  .exists?(["metadata->>'image_attachment_id' = ?", image_attachment_id.to_s])
    end

    def custom_product_created(custom_product)
      user = custom_product.user
      return unless user

      presenter = CustomProductPresenter.new(custom_product)
      upsert_activity!(
        user_id: user.id,
        subject: custom_product,
        verb: 'custom_product_created',
        occurred_at: custom_product.created_at,
        metadata: {
          'display_name' => presenter.display_name,
          'url' => presenter.show_path
        }
      )
    end

    def setup_created(setup)
      user = setup.user
      return unless user

      upsert_activity!(
        user_id: user.id,
        subject: setup,
        verb: 'setup_created',
        occurred_at: setup.created_at,
        metadata: setup_metadata(setup)
      )
    end

    def setup_made_public(setup, at: Time.current)
      user = setup.user
      return unless user

      UserActivity.create!(
        user_id: user.id,
        subject: setup,
        verb: 'setup_made_public',
        occurred_at: at,
        metadata: setup_metadata(setup)
      )
    end

    def setup_made_private(setup, at: Time.current)
      user = setup.user
      return unless user

      UserActivity.create!(
        user_id: user.id,
        subject: setup,
        verb: 'setup_made_private',
        occurred_at: at,
        metadata: setup_metadata(setup)
      )
    end

    def setup_metadata(setup)
      {
        'display_name' => setup.name,
        'private' => setup.private,
        'setup_id' => setup.id
      }.compact
    end

    def setup_product_added(setup_possession, occurred_at: Time.current)
      setup = setup_possession.setup
      possession = setup_possession.possession
      user = setup&.user
      return unless user && setup && possession
      return unless setup.user_id == possession.user_id

      UserActivity.create!(
        user_id: user.id,
        subject: setup,
        verb: 'setup_product_added',
        occurred_at:,
        metadata: setup_product_activity_metadata(setup, possession)
      )
    end

    def setup_product_removed(user:, setup:, possession:, occurred_at: Time.current)
      return unless user && setup && possession
      return unless setup.user_id == possession.user_id

      UserActivity.create!(
        user_id: user.id,
        subject: setup,
        verb: 'setup_product_removed',
        occurred_at:,
        metadata: setup_product_activity_metadata(setup, possession)
      )
    end

    def setup_product_activity_metadata(setup, possession)
      presenter = PossessionPresenterService.map_to_presenters([possession]).first
      stringify_keys(
        setup_metadata(setup).merge(
          'possession_id' => possession.id,
          'recorded_while_setup_private' => setup.private,
          'product_display_name' => presenter.display_name,
          'product_id' => possession.product_id,
          'product_variant_id' => possession.product_variant_id,
          'custom_product_id' => possession.custom_product_id
        ).compact
      )
    end

    def event_attendance(attendee)
      user = attendee.user
      event = attendee.event
      return unless user && event

      upsert_activity!(
        user_id: user.id,
        subject: attendee,
        verb: 'event_attendance',
        occurred_at: attendee.created_at,
        metadata: event_metadata(event)
      )
    end

    def followed_by_user(follow)
      followed = follow.followed
      follower = follow.follower
      return unless followed && follower

      upsert_activity!(
        user_id: followed.id,
        subject: follow,
        verb: 'followed_by_user',
        occurred_at: follow.created_at,
        metadata: follower_metadata(follower)
      )
    end

    def hide_followed_by_user(follow)
      return if follow.id.blank?

      # update_all avoids re-validating subject after the UserFollow row is destroyed.
      UserActivity.visible
                  .where(subject_type: follow.class.name, subject_id: follow.id, verb: 'followed_by_user')
                  # rubocop:disable Rails/SkipsModelValidations
                  .update_all(hidden_at: Time.current, updated_at: Time.current)
      # rubocop:enable Rails/SkipsModelValidations
    end

    def event_attendance_cancelled(user:, event:, occurred_at: Time.current)
      return unless user && event

      UserActivity.create!(
        user_id: user.id,
        subject: event,
        verb: 'event_attendance_cancelled',
        occurred_at:,
        metadata: event_metadata(event)
      )
    end

    def event_metadata(event)
      {
        'display_name' => event.name,
        'url' => Rails.application.routes.url_helpers.event_path(year: event.calendar_year, slug: event.friendly_id),
        'event_start_date' => event.start_date&.iso8601,
        'event_end_date' => event.end_date&.iso8601
      }.compact
    end

    def follower_metadata(follower)
      {
        'follower_id' => follower.id,
        'follower_user_name' => follower.user_name,
        'url' => follower.profile_path
      }
    end

    private

    def hide_stale_possession_activities!(possession, expected_verbs)
      stale_verbs = UserActivities::PossessionSync::POSSESSION_VERBS - expected_verbs
      return if stale_verbs.empty?

      UserActivity.visible.where(subject: possession, verb: stale_verbs).find_each do |activity|
        activity.update!(hidden_at: Time.current)
      end
    end

    def upsert_activity!(user_id:, subject:, verb:, occurred_at:, metadata: {})
      activity = UserActivity.find_or_initialize_by(
        user_id:,
        subject:,
        verb:
      )
      activity.occurred_at = occurred_at if activity.new_record? || activity.occurred_at.blank?
      activity.metadata = (activity.metadata || {}).merge(stringify_keys(metadata))
      activity.save!
    end

    def record_possession_image_activity!(possession, verb:, occurred_at:, attachment: nil, presenter: nil)
      user = possession.user
      return unless user

      attachment_id = possession_image_attachment_id(attachment)
      return if attachment_id.blank?
      return if possession_image_activity_exists?(
        user_id: user.id, possession:, verb:, image_attachment_id: attachment_id
      )

      presenter ||= PossessionPresenterService.map_to_presenters([possession]).first
      UserActivity.create!(
        user_id: user.id,
        subject: possession,
        verb:,
        occurred_at:,
        metadata: stringify_keys(
          {
            'display_name' => presenter&.display_name,
            'url' => presenter&.show_path,
            'period_from' => possession.period_from&.iso8601,
            'period_to' => possession.period_to&.iso8601,
            'possession_created_at' => possession.created_at&.iso8601,
            'image_attachment_id' => attachment_id
          }.compact
        )
      )
    end

    def possession_image_attachment_id(attachment)
      image_attachment_id(attachment)
    end

    def record_user_profile_image_activity!(user, verb:, occurred_at:, attachment: nil)
      return unless user&.persisted?

      attachment_id = image_attachment_id(attachment)
      return if attachment_id.blank?
      return if user_profile_image_activity_exists?(
        user_id: user.id, user:, verb:, image_attachment_id: attachment_id
      )

      UserActivity.create!(
        user_id: user.id,
        subject: user,
        verb:,
        occurred_at:,
        metadata: stringify_keys(
          {
            'display_name' => user.user_name,
            'url' => user.profile_path,
            'image_attachment_id' => attachment_id
          }.compact
        )
      )
    end

    def image_attachment_id(attachment)
      case attachment
      when ActiveStorage::Attachment
        attachment.id
      when Integer
        attachment
      else
        attachment.presence&.to_i
      end
    end

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
