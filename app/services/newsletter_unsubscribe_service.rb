# frozen_string_literal: true

class NewsletterUnsubscribeService
  def self.generate_token(email)
    return if secret.blank?

    user = find_user_by_email(email)
    return unless user

    url_safe_verifier.generate(user.id.to_s)
  end

  def self.decode_token(token)
    return if secret.blank? || token.blank?

    normalized = normalize_token(token)
    identifier = safe_verify(url_safe_verifier, normalized) ||
                 safe_verify(legacy_verifier, normalized) ||
                 safe_verify(sha256_verifier, normalized)
    resolve_user(identifier) if identifier.present?
  end

  def self.secret
    ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET', nil)&.strip
  end

  def self.url_safe_verifier
    ActiveSupport::MessageVerifier.new(secret, url_safe: true)
  end

  def self.legacy_verifier
    ActiveSupport::MessageVerifier.new(secret)
  end

  def self.sha256_verifier
    ActiveSupport::MessageVerifier.new(secret, digest: 'SHA256')
  end

  def self.normalize_token(token)
    value = CGI.unescape(token.to_s.tr(' ', '+'))
    value.tr(' ', '+')
  end

  def self.safe_verify(verifier, token)
    verifier.verified(token)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.find_user_by_email(email)
    User.where('lower(email) = ?', email.to_s.downcase.strip).first
  end

  def self.resolve_user(identifier)
    if identifier.to_s.include?('@')
      find_user_by_email(identifier)
    else
      User.find_by(id: identifier)
    end
  end
end
