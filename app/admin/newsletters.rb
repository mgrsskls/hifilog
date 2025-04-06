ActiveAdmin.register Newsletter do
  permit_params :content

  after_create do |newsletter|
    recipients = User.where(receives_newsletter: true)

    recipients.each do |recipient|
      UserMailer.newsletter_email(
        recipient,
        newsletter.content
      ).deliver
    end
  end
end
