# frozen_string_literal: true

require 'test_helper'

class ApplicationMailerTest < ActionMailer::TestCase
  test 'sets default sender and mailer layout' do
    assert_equal '"hifilog.com" <info@mail.hifilog.com>', ApplicationMailer.default[:from]
    assert_equal 'mailer', ApplicationMailer._layout
  end
end
