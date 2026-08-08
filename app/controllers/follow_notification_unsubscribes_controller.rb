# frozen_string_literal: true

# Public, token-based follow-notification unsubscribe. See TokenUnsubscribe.
class FollowNotificationUnsubscribesController < ApplicationController
  include TokenUnsubscribe

  private

  def unsubscribe_service
    FollowNotificationUnsubscribeService
  end

  def unsubscribe_attribute
    :receives_follow_notifications
  end

  def success_message
    I18n.t('user_follow.notifications.unsubscribed')
  end

  def invalid_message
    I18n.t('user_follow.notifications.invalid_unsubscribe_link')
  end
end
