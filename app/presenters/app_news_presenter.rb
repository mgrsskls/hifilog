class AppNewsPresenter
  delegate_missing_to :@news

  def initialize(news)
    @news = news
  end

  def formatted_text
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new)

    # rubocop:disable Rails/OutputSafety
    markdown.render(@news.text).html_safe
    # rubocop:enable Rails/OutputSafety
  end
end
