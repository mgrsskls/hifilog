module NewsletterHelper
  def generate_unsubscribe_hash(email)
    verifier = ActiveSupport::MessageVerifier.new(ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET',
                                                            'NEWSLETTER_UNSUBSCRIBE_SECRET'))
    verifier.generate(email)
  end

  def verify_unsubscribe_hash(token)
    verifier = ActiveSupport::MessageVerifier.new(ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET',
                                                            'NEWSLETTER_UNSUBSCRIBE_SECRET'))
    verifier.verified(token)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end
end
