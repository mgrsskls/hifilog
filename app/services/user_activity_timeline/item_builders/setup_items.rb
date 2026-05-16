# frozen_string_literal: true

module UserActivityTimeline::ItemBuilders::SetupItems
  private

  def setup_activity_item(activity)
    return nil unless setup_activity_visible?(activity)

    setup = activity.subject
    meta = activity.metadata || {}
    display_name = setup&.name.presence || meta['display_name'].presence || '—'
    url = setup_activity_url(setup, meta)

    setup_id = setup&.id || meta['setup_id'].presence&.to_i

    UserActivityTimeline::Item.new(
      verb: activity.verb_sym,
      logged_at: activity.occurred_at,
      display_name:,
      url:,
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id:
    )
  end

  def setup_product_activity_item(activity)
    return nil unless setup_activity_visible?(activity)

    setup = activity.subject
    meta = activity.metadata || {}
    return nil if activity_recorded_while_setup_private?(meta)

    possession = @lookup.possession(meta['possession_id']) if meta['possession_id'].present?

    product_name = meta['product_display_name'].presence || '—'
    product_url = @lookup.setup_product_activity_product_url(meta, possession)
    setup_name = setup&.name.presence || meta['display_name'].presence || '—'
    setup_url = setup_activity_url(setup, meta)
    setup_id = setup&.id || meta['setup_id'].presence&.to_i

    UserActivityTimeline::Item.new(
      verb: activity.verb_sym,
      logged_at: activity.occurred_at,
      display_name: product_name,
      url: product_url,
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name:,
      setup_url:,
      setup_id:
    )
  end

  def setup_activity_visible?(activity)
    setup = activity.subject
    meta = activity.metadata || {}
    if setup.is_a?(Setup)
      !setup.private
    else
      meta['private'] != true
    end
  end

  def activity_recorded_while_setup_private?(meta)
    ActiveModel::Type::Boolean.new.cast(meta['private']) ||
      ActiveModel::Type::Boolean.new.cast(meta['recorded_while_setup_private'])
  end
end
