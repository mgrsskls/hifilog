class Newsletter < ApplicationRecord
  def send_test(email, user_name)
    UserMailer.newsletter_email(
      email,
      user_name,
      content
    ).deliver
  end

  def send_to_all
    recipients = User.where(receives_newsletter: true)

    recipients.each do |recipient|
      UserMailer.newsletter_email(
        recipient.email,
        recipient.user_name,
        content
      ).deliver
    end
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[content created_at id updated_at]
  end
  # :nocov:
end
