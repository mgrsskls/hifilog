# frozen_string_literal: true

module Description
  extend ActiveSupport::Concern
  include ActionView::Helpers::SanitizeHelper

  ALLOWED_DESCRIPTION_TAGS = %w[p b i strong em br ul ol li del blockquote].freeze

  def formatted_description
    return markdown_to_safe_html(description) if description.present?
    return fallback_description if fallback_description.present?

    nil
  end

  def fallback_description
    nil
  end

  def markdown_to_safe_html(source)
    sanitize(
      Commonmarker.to_html(source,
                           options: { extension: { strikethrough: false, tagfilter: false, table: false,
                                                   autolink: false, tasklist: false } }),
      tags: ALLOWED_DESCRIPTION_TAGS
    )
  end
end
