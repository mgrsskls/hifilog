# frozen_string_literal: true

# Public, token-based newsletter unsubscribe. See TokenUnsubscribe.
class NewsletterUnsubscribesController < ApplicationController
  include TokenUnsubscribe

  private

  def unsubscribe_service
    NewsletterUnsubscribeService
  end

  def unsubscribe_attribute
    :receives_newsletter
  end

  def success_message
    I18n.t('newsletter.messages.unsubscribed')
  end

  def invalid_message
    I18n.t('newsletter.messages.invalid_unsubscribe_link')
  end
end
