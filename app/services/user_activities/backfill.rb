# frozen_string_literal: true

class UserActivities::Backfill
  class << self
    def run_all
      unless ActiveRecord::Base.connection.column_exists?(:possessions, :moved_to_previous_at)
        raise <<~MSG.squish
          user_activities:backfill requires possessions.moved_to_previous_at.
          Apply pending migrations: bin/rails db:migrate
        MSG
      end

      User.find_each do |user|
        user.possessions.find_each do |p|
          UserActivities::Recorder.sync_possession(p)
          backfill_possession_image_uploads(p) if p.images.attached?
        end
        user.custom_products.find_each { |cp| UserActivities::Recorder.custom_product_created(cp) }
        user.setups.find_each { |s| UserActivities::Recorder.setup_created(s) }
        user.setup_possessions.find_each { |sp| backfill_setup_product_added(sp) }
        user.event_attendees.find_each { |ea| UserActivities::Recorder.event_attendance(ea) }
        backfill_user_profile_image_upload(user, attachment_name: :avatar) if user.avatar.attached?
        backfill_user_profile_image_upload(user, attachment_name: :decorative_image) if user.decorative_image.attached?
      end
    end

    def backfill_user_profile_image_upload(user, attachment_name:)
      attachment = user.public_send(attachment_name).attachment
      return unless attachment

      verb = "#{attachment_name}_uploaded"
      return if UserActivities::Recorder.user_profile_image_activity_exists?(
        user_id: user.id,
        user:,
        verb:,
        image_attachment_id: attachment.id
      )

      UserActivities::Recorder.public_send(
        verb,
        user,
        occurred_at: attachment.created_at,
        image_attachment: attachment
      )
    end

    def backfill_possession_image_uploads(possession)
      user = possession.user
      return unless user

      possession.images.attachments.each do |attachment|
        next if UserActivities::Recorder.possession_image_activity_exists?(
          user_id: user.id,
          possession:,
          verb: 'possession_image_uploaded',
          image_attachment_id: attachment.id
        )

        UserActivities::Recorder.possession_image_uploaded(
          possession,
          occurred_at: attachment.created_at,
          image_attachment: attachment
        )
      end
    end

    # +setup_possessions+ has no +created_at+; use a stable synthetic time. Skip when a matching row already exists
    # so backfill stays idempotent (same index shape as live +setup_product_added+ creates).
    def backfill_setup_product_added(setup_possession)
      setup = setup_possession.setup
      possession = setup_possession.possession
      user = setup&.user
      return unless user && setup && possession
      return unless setup.user_id == possession.user_id

      if UserActivity.where(user_id: user.id, subject: setup, verb: 'setup_product_added')
                     .exists?(["metadata->>'possession_id' = ?", possession.id.to_s])
        return
      end

      occurred_at = [setup.created_at, possession.created_at].compact.max
      UserActivities::Recorder.setup_product_added(setup_possession, occurred_at:)
    end
  end
end
