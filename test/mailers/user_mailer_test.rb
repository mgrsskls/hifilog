require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  test 'newsletter_email' do
    mail = UserMailer.newsletter_email(users(:one), 'Hi %user_name%')
    assert_equal 'hifilog.com Newsletter', mail.subject
    assert_equal [users(:one).email], mail.to
    assert_equal ['newsletter@mail.hifilog.com'], mail.from
    assert_match 'Hi one_username', mail.body.encoded
  end
end
