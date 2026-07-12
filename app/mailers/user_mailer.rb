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
end
