module FormatHelper
  def format_partial_date(year, month, day)
    return nil if year.nil?
    return year.to_s if month.nil?

    formatted_month = month.to_s.rjust(2, '0')

    return "#{year}&thinsp;/&thinsp;#{formatted_month}" if day.nil?

    formatted_day = day.to_s.rjust(2, '0')

    "#{year}&thinsp;/&thinsp;#{formatted_month}&thinsp;/&thinsp;#{formatted_day}"
  end

  def format_date(date)
    date.strftime('%Y&thinsp;/&thinsp;%m&thinsp;/&thinsp;%d')
  end

  def format_iso_date(date)
    date.strftime('%Y-%m-%dT00:00+0000')
  end

  def format_datetime(date)
    date.strftime('%Y&thinsp;/&thinsp;%m&thinsp;/&thinsp;%d - %H:%M')
  end

  def format_iso_datetime(datetime)
    datetime.strftime('%Y-%m-%dT%H:%M+0000')
  end

  def markdown_to_html(content)
    Commonmarker.to_html(
      content,
      options: {
        render: {
          unsafe: true
        }
      }
    )
  end
end
