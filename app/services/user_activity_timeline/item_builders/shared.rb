# frozen_string_literal: true

module UserActivityTimeline::ItemBuilders::Shared
  private

  def parse_meta_date(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)&.to_date
  rescue ArgumentError, TypeError
    nil
  end

  def parse_meta_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def setup_activity_url(setup, meta)
    if setup
      user_setup_path(user_id: @user.user_name.downcase, setup: setup.id)
    elsif (sid = meta['setup_id'].presence&.to_i)&.positive?
      user_setup_path(user_id: @user.user_name.downcase, setup: sid)
    else
      meta['url'].presence || '#'
    end
  end
end
