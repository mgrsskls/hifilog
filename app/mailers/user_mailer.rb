class UserMailer < ApplicationMailer
  include FormatHelper
  include NewsletterHelper

  def newsletter_email(email, user_name, content)
    @content = markdown_to_html content.sub('%user_name%', user_name)
    @unsubscribe_hash = generate_unsubscribe_hash(email)
    @email = email

    headers['List-Unsubscribe'] = "<#{newsletters_unsubscribe_url(email: @email, hash: @unsubscribe_hash)}>"

    mail(
      from: 'HiFi Log Newsletter <newsletter@mail.hifilog.com>',
      to: email,
      subject: I18n.t('newsletter.subject')
    )
  end
end
