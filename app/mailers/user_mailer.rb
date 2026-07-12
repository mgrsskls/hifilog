# frozen_string_literal: true

class UserMailer < ApplicationMailer
  include FormatHelper

  def newsletter_email(email, user_name, content)
    @content_text = content.sub('%user_name%', user_name)
    @content_html = markdown_to_html(@content_text)
    @unsubscribe_hash = NewsletterUnsubscribeService.generate_token(email)
    @unsubscribe_url = newsletters_unsubscribe_url(hash: @unsubscribe_hash) if @unsubscribe_hash.present?

    if @unsubscribe_url.present?
      headers['List-Unsubscribe'] = "<#{@unsubscribe_url}>"
      headers['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'
    end

    mail(
      from: 'HiFi Log Newsletter <newsletter@mail.hifilog.com>',
      to: email,
      subject: I18n.t('newsletter.subject')
    )
  end

  def followed_notification(follow)
    @follower = follow.follower
    @followed = follow.followed
    # Hidden followers are announced by name only; their profile is not reachable.
    @follower_profile_url = user_url(id: @follower.lowercase_user_name) unless @follower.hidden?
    @unsubscribe_hash = FollowNotificationUnsubscribeService.generate_token(@followed.email)
    @unsubscribe_url = follow_notifications_unsubscribe_url(hash: @unsubscribe_hash) if @unsubscribe_hash.present?

    if @unsubscribe_url.present?
      headers['List-Unsubscribe'] = "<#{@unsubscribe_url}>"
      headers['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'
    end

    mail(
      to: @followed.email,
      subject: I18n.t('user_follow.mailer.subject', follower_name: @follower.user_name)
    )
  end
end
