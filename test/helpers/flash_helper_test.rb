# frozen_string_literal: true

require 'test_helper'

class FlashHelperTest < ActionView::TestCase
  include FlashHelper

  test 'flash_message_html escapes user content in locale markup' do
    message = I18n.t('setup.messages.deleted', name: 'Tom & Jerry <script>alert(1)</script>')
    html = flash_message_html(message)

    assert_not_includes html, '<script>'
    assert_includes html, 'Tom &amp; Jerry'
    assert_includes html, '<b>'
  end

  test 'flash_message_html preserves safe links from helpers' do
    link = ActionController::Base.helpers.link_to('My setup', '/dashboard/setups/1')
    message = I18n.t('setup.messages.created', link: link)
    html = flash_message_html(message)

    assert_includes html, '<a href="/dashboard/setups/1">'
    assert_includes html, 'My setup'
  end

  test 'flash_message_html strips dangerous attributes' do
    html = flash_message_html('<a href="/ok" onclick="alert(1)">link</a>')

    assert_includes html, 'href="/ok"'
    assert_not_includes html, 'onclick'
  end
end
