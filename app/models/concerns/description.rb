module Description
  extend ActiveSupport::Concern

  def formatted_description
    return if description.blank?

    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(hard_wrap: true)).render(description)
  end
end
