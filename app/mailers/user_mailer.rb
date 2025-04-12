class UserMailer < ApplicationMailer
  include FormatHelper
  include NewsletterHelper

  def newsletter_email(recipient, content)
    @content = markdown_to_html content.sub('%user_name%', recipient.user_name)
    @unsubscribe_hash = generate_unsubscribe_hash(recipient.email)
    @email = recipient.email

    headers['List-Unsubscribe'] = "<#{newsletters_unsubscribe_url(email: @email, hash: @unsubscribe_hash)}>"

    mail(
      from: 'HiFi Log Newsletter <newsletter@mail.hifilog.com>',
      to: recipient.email,
      subject: I18n.t('newsletter.subject')
    )
  end
end
