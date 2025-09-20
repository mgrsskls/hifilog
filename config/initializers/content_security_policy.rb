# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header


unless ENV['DISABLE_CSP']
  Rails.application.configure do
    config.content_security_policy do |policy|
      policy.base_uri    :self
      policy.default_src :self
      policy.font_src    :none
      policy.img_src     :self, :data, ENV['CDN_HOST'], 'https://*.adtrafficquality.google'
      policy.object_src  :none
      policy.script_src  :self, ENV['CDN_HOST'], 'https://pagead2.googlesyndication.com'
      policy.style_src   :self, :unsafe_inline, ENV['CDN_HOST'], 'https://fonts.googleapis.com'
      policy.frame_src   :self, 'https://pagead2.googlesyndication.com', 'https://*.adtrafficquality.google', 'https://googleads.g.doubleclick.net', 'https://www.google.com'
      policy.connect_src :self, 'https://pagead2.googlesyndication.com', 'https://*.adtrafficquality.google', 'https://csi.gstatic.com'
      # Specify URI for violation reports
      policy.report_uri ENV['SENTRY_CSP_REPORT_URI'] if ENV['SENTRY_CSP_REPORT_URI'].present?
    end
    #
    #   # Generate session nonces for permitted importmap and inline scripts
    # See https://github.com/rails/rails/issues/48463 and https://github.com/rails/rails/pull/48510
    config.content_security_policy_nonce_generator = ->(request) { request.session[:nonce] ||= SecureRandom.hex }
    config.content_security_policy_nonce_directives = %w(script-src)
    #
    #   # Report violations without enforcing the policy.
    #   # config.content_security_policy_report_only = true
  end
end
