module Description
  extend ActiveSupport::Concern
  include ActionView::Helpers::SanitizeHelper

  def formatted_description
    return if description.blank?

    sanitize(
      Commonmarker.to_html(
        description,
        options: {
          extension: {
            strikethrough: false,
            tagfilter: false,
            table: false,
            autolink: false,
            tasklist: false,
          }
        }
      ),
      tags: %w[p b i strong em br ul ol li del blockquote]
    )
  end
end
