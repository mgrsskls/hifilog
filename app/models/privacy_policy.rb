# frozen_string_literal: true

# Tracks the published privacy policy revision shown to users at sign-up.
class PrivacyPolicy
  # Increment when users must accept the updated policy.
  VERSION = 'v2'

  # Increment when the published text changes but re-acceptance is not required.
  CONTENT_REVISION = 2

  CACHE_KEY = "/static/privacy_policy/#{VERSION}/#{CONTENT_REVISION}".freeze
end
