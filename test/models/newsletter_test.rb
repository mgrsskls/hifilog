# frozen_string_literal: true

require 'test_helper'

class NewsletterTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test 'send_test delivers one synchronous email' do
    newsletter = newsletters(:one)
    recipient = users(:one)

    assert_emails 1 do
      newsletter.send_test(recipient.email, recipient.user_name)
    end

    delivered = ActionMailer::Base.deliveries.last
    assert_includes delivered.to, recipient.email
  end

  test 'send_to_all queues one synchronous email per opt-in subscriber' do
    newsletter = newsletters(:one)
    opted_in_count = User.where(receives_newsletter: true).count

    assert_operator opted_in_count, :>, 0

    before = ActionMailer::Base.deliveries.size
    newsletter.send_to_all
    assert_equal opted_in_count, ActionMailer::Base.deliveries.size - before

    opted_emails = User.where(receives_newsletter: true).pluck(:email)
    mailed = ActionMailer::Base.deliveries.last(opted_in_count).flat_map(&:to).sort.uniq.sort
    assert_equal opted_emails.sort, mailed.sort
  end
end
