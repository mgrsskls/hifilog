module Description
  extend ActiveSupport::Concern

  def formatted_description
    return if description.blank?

    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(description)
  end
end
