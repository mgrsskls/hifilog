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
        user.possessions.find_each { |p| UserActivities::Recorder.sync_possession(p) }
        user.custom_products.find_each { |cp| UserActivities::Recorder.custom_product_created(cp) }
        user.setups.find_each { |s| UserActivities::Recorder.setup_created(s) }
        user.setup_possessions.find_each { |sp| backfill_setup_product_added(sp) }
        user.event_attendees.find_each { |ea| UserActivities::Recorder.event_attendance(ea) }
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
