module FormatHelper
  def formatted_date(date)
    date.strftime('%Y-%m-%dT00:00+0000')
  end

  def formatted_datetime(datetime)
    datetime.strftime('%Y-%m-%dT%H:%M+0000')
  end

  def markdown_to_html(content)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(hard_wrap: true))
    markdown.render(content)
  end
end
