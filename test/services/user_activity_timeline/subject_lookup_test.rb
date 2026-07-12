# frozen_string_literal: true

require 'test_helper'

class UserActivityTimeline::SubjectLookupTest < ActiveSupport::TestCase
  test 'possession_gallery_image resolves uploader without extra possession queries' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 8, 2, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
    end
    travel_to(Time.zone.local(2026, 8, 2, 11, 0, 0)) do
      possession.update!(images: [one_by_one_png_upload(filename: 'lookup-uploader.png')])
    end

    activity = UserActivity.find_by!(user: user, subject: possession, verb: 'possession_image_uploaded')
    attachment = possession.images_attachments.last
    lookup = UserActivityTimeline::SubjectLookup.new(user: user, activities: [activity])

    queries = count_possession_queries do
      3.times do
        presenter = lookup.possession_gallery_image(attachment.id)
        assert_equal possession.user, presenter.user
      end
    end

    assert_equal 0, queries
  end

  private

  def count_possession_queries(&)
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      count += 1 if payload[:sql].match?(/\bFROM "possessions"\b/i)
    end

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end
end
