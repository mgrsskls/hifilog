# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header


unless ENV['DISABLE_CSP']
  Rails.application.configure do
    config.content_security_policy do |policy|
      policy.default_src :self, :https
      policy.font_src    :self, :https, :data
      policy.img_src     :self, :https, :data, ENV['CDN_HOST']
      policy.object_src  :none
      policy.script_src  :self, :https, ENV['CDN_HOST']
      policy.style_src   :self, :https, :unsafe_inline, ENV['CDN_HOST']
      # Specify URI for violation reports
      # policy.report_uri "/csp-violation-report-endpoint"
    end
    #
    #   # Generate session nonces for permitted importmap and inline scripts
    config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
    config.content_security_policy_nonce_directives = %w(script-src)
    #
    #   # Report violations without enforcing the policy.
    #   # config.content_security_policy_report_only = true
  end
end
