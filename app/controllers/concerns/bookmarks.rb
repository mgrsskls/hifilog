module Bookmarks
  extend ActiveSupport::Concern

  def get_grouped_sub_categories(bookmarks: [])
    bookmarks
      .map(&:product)
      .flat_map(&:sub_categories)
      .sort_by(&:name)
      .uniq
      .group_by(&:category)
      .sort_by { |category| category[0].order }
      .map do |c|
        [
          c[0],
          c[1].map do |sub_category|
            {
              name: sub_category.name,
              friendly_id: sub_category.friendly_id,
              path: dashboard_bookmarks_path(category: sub_category.friendly_id)
            }
          end
        ]
      end
  end
end
