# frozen_string_literal: true

require 'test_helper'

class NewsletterHelperTest < ActionView::TestCase
  teardown do
    ENV.delete('NEWSLETTER_UNSUBSCRIBE_SECRET')
  end

  test 'tokens round trip when unsubscribe secret exists' do
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = SecureRandom.hex(32)

    email = 'reader@example.com'
    token = generate_unsubscribe_hash(email)

    assert token.present?
    assert_equal email, verify_unsubscribe_hash(token)
  end

  test 'helpers return nil when secret is absent' do
    ENV.delete('NEWSLETTER_UNSUBSCRIBE_SECRET')

    assert_nil generate_unsubscribe_hash('reader@example.com')
    assert_nil verify_unsubscribe_hash('any-token')
  end

  test 'bogus tokens decode to nil' do
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = SecureRandom.hex(32)

    assert_nil verify_unsubscribe_hash('invalid')
  end
end
