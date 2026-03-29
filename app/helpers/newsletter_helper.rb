# frozen_string_literal: true

module NewsletterHelper
  def generate_unsubscribe_hash(email)
    return unless verifier

    verifier.generate(email)
  end

  def verify_unsubscribe_hash(token)
    return unless verifier

    verifier.verified(token)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  private

  def verifier
    secret = ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET', nil)

    return unless secret

    ActiveSupport::MessageVerifier.new(secret)
  end
end
