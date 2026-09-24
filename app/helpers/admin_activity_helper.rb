# frozen_string_literal: true

# Helpers for the activity pages in ActiveAdmin (User Activities, Product & Brand Activities).
module AdminActivityHelper
  # Date on the first line, time below, so the column stays narrow.
  def admin_activity_timestamp(time)
    return if time.nil?

    safe_join([time.strftime('%d.%m.%Y'), tag.br, tag.small(time.strftime('%H:%M'))])
  end
end
