# frozen_string_literal: true

module FormatHelper
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

  SCRIPT_TAG_PATTERN = %r{<script\b[^>]*>[\s\S]*?</script>}i

  def markdown_to_html(content)
    html = Commonmarker.to_html(
      content,
      options: {
        render: {
          unsafe: true
        }
      }
    )
    strip_script_tags(html)
  end

  def strip_script_tags(html)
    html.gsub(SCRIPT_TAG_PATTERN, '')
  end
end
