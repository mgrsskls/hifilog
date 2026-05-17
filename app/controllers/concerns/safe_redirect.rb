# frozen_string_literal: true

module SafeRedirect
  extend ActiveSupport::Concern

  DANGEROUS_SCHEME_PATTERN = /\A\s*(?:javascript|data|vbscript):/i

  included do
    helper_method :safe_redirect_path if respond_to?(:helper_method, true)
  end

  class << self
    def resolve(url, host:, port:)
      normalized = url.to_s.strip
      return nil if normalized.blank?
      return nil if protocol_relative?(normalized)
      return nil if dangerous_scheme?(normalized)

      uri = URI.parse(normalized)
      return nil unless same_host?(uri, host: host, port: port)

      path = extract_path(uri, normalized)
      return nil unless safe_path?(path)

      path
    rescue URI::InvalidURIError
      nil
    end

    private

    def protocol_relative?(url)
      url.start_with?('//')
    end

    def dangerous_scheme?(url)
      url.match?(DANGEROUS_SCHEME_PATTERN)
    end

    def same_host?(uri, host:, port:)
      return true if uri.host.blank?

      uri.host.casecmp?(host) && uri_port(uri) == port.to_i
    end

    def uri_port(uri)
      uri.port || uri.default_port
    end

    def extract_path(uri, normalized)
      return unless uri.host.present? || normalized.start_with?('/')

      path = uri.path.presence || '/'
      path = "#{path}?#{uri.query}" if uri.query.present?
      path = "#{path}##{uri.fragment}" if uri.fragment.present?
      path
    end

    def safe_path?(path)
      return false if path.blank?
      return false unless path.start_with?('/')

      path_only = path.split('?', 2).first
      return false if path_only.include?('\\')
      return false if path_only.match?(%r{//|\\})

      decoded = CGI.unescape(path_only)
      return false if decoded.match?(%r{//|\\})
      return false if decoded.include?('..')

      true
    end
  end

  private

  def safe_redirect_path(url)
    SafeRedirect.resolve(url, host: request.host, port: request.port)
  end

  def redirect_to_safe_path(url, fallback:)
    redirect_to safe_redirect_path(url) || fallback
  end
end
