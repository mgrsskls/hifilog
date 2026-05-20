# frozen_string_literal: true

Rails.application.config.action_dispatch.default_headers.merge!(
  'Referrer-Policy' => 'strict-origin-when-cross-origin',
  'X-Frame-Options' => 'SAMEORIGIN'
)
