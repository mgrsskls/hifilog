# frozen_string_literal: true

module FlashHelper
  include ActionView::Helpers::SanitizeHelper

  FLASH_ALLOWED_TAGS = %w[a b i strong em small].freeze
  FLASH_ALLOWED_ATTRIBUTES = %w[href].freeze

  def flash_message_html(message)
    sanitize(
      message.to_s,
      tags: FLASH_ALLOWED_TAGS,
      attributes: FLASH_ALLOWED_ATTRIBUTES
    )
  end
end
