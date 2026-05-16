# frozen_string_literal: true

module UserActivityTimeline::ItemBuilders::CustomProductItems
  private

  def custom_product_activity_item(activity)
    cp = activity.subject
    if cp.is_a?(CustomProduct)
      presenter = CustomProductPresenter.new(cp)
      display_name = presenter.display_name
      url = presenter.show_path
    else
      meta = activity.metadata || {}
      display_name = meta['display_name'].presence || '—'
      url = meta['url'].presence || '#'
    end

    UserActivityTimeline::Item.new(
      verb: :custom_product_created,
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
      setup_id: nil
    )
  end
end
