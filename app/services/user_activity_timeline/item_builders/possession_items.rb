# frozen_string_literal: true

module UserActivityTimeline::ItemBuilders::PossessionItems
  private

  def possession_activity_item(activity)
    return nil unless activity.subject_type == 'Possession'

    possession = @lookup.possession(activity.subject_id)
    return nil unless possession

    presenter = @lookup.possession_presenter(possession)
    return nil unless presenter

    meta = activity.metadata || {}
    UserActivityTimeline::Item.new(
      verb: activity.verb_sym,
      logged_at: activity.occurred_at,
      display_name: presenter.display_name,
      url: presenter.show_path,
      period_from: possession.period_from.presence || parse_meta_date(meta['period_from']),
      period_to: possession.period_to.presence || parse_meta_date(meta['period_to']),
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: possession.created_at.presence || parse_meta_time(meta['possession_created_at']),
      setup_name: nil,
      setup_url: nil,
      setup_id: nil,
      possession_id: nil,
      gallery_image: nil
    )
  end

  def possession_image_uploaded_activity_item(activity)
    return nil unless activity.subject_type == 'Possession'

    possession = @lookup.possession(activity.subject_id)
    return nil unless possession

    presenter = @lookup.possession_presenter(possession)
    return nil unless presenter

    meta = activity.metadata || {}
    attachment_id = meta['image_attachment_id'].presence&.to_i
    gallery_image = @lookup.possession_gallery_image(attachment_id)
    return nil unless gallery_image

    UserActivityTimeline::Item.new(
      verb: activity.verb_sym,
      logged_at: activity.occurred_at,
      display_name: presenter.display_name,
      url: presenter.show_path,
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil,
      possession_id: possession.id,
      gallery_image:
    )
  end
end
