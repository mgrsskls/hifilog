# frozen_string_literal: true

module FormatHelper
  MARKDOWN_ALLOWED_TAGS = %w[a img p b strong hr ul ol li h1 h2 h3 h4 h5 h6 blockquote em time br].freeze
  MARKDOWN_ALLOWED_ATTRIBUTES = %w[href src alt rel height width loading].freeze
  def format_partial_date(year, month, day)
    return nil if year.nil?
    return year.to_s if month.nil?

    formatted_month = month.to_s.rjust(2, '0')

    return "#{year}/#{formatted_month}" if day.nil?

    formatted_day = day.to_s.rjust(2, '0')

    "#{year}/#{formatted_month}/#{formatted_day}"
  end

  def format_date(date)
    date.strftime('%Y/%m/%d')
  end

  def format_iso_date(date)
    date.strftime('%Y-%m-%dT00:00+0000')
  end

  def format_datetime(date)
    date.strftime('%Y/%m/%d - %H:%M')
  end

  def format_iso_datetime(datetime)
    datetime.strftime('%Y-%m-%dT%H:%M+0000')
  end

  def markdown_to_html(content)
    ActionController::Base.helpers.sanitize(
      Commonmarker.to_html(content, options: {
                             render: {
                               unsafe: true
                             }
                           }),
      tags: MARKDOWN_ALLOWED_TAGS,
      attributes: MARKDOWN_ALLOWED_ATTRIBUTES
    )
  end
end
