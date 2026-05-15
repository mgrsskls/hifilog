# frozen_string_literal: true

# Maps +UserActivity+ records to feed +Item+ structs.
module UserActivityTimeline::ItemBuilders
  include Shared
  include PossessionItems
  include CustomProductItems
  include SetupItems
  include EventItems

  private

  def activity_to_item(activity)
    case activity.verb
    when 'added_to_collection', 'added_to_previous', 'moved_to_previous'
      possession_activity_item(activity)
    when 'custom_product_created'
      custom_product_activity_item(activity)
    when 'setup_created', 'setup_made_public'
      setup_activity_item(activity)
    when 'setup_made_private'
      nil
    when 'setup_product_added', 'setup_product_removed'
      setup_product_activity_item(activity)
    when 'event_attendance'
      event_attendance_activity_item(activity)
    when 'event_attendance_cancelled'
      event_cancelled_activity_item(activity)
    end
  end
end
