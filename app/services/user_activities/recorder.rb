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

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
