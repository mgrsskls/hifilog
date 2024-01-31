module ApplicationHelper
  ABC = ('a'..'z').to_a.freeze

  def current_page?(test_path)
    request.path == test_path
  end

  def active_menu_state(active_menu, page)
    ' aria-current="true"'.html_safe if active_menu == page
  end

  def active_dashboard_menu_state(active_dashboard_menu, page)
    ' aria-current="true"'.html_safe if active_dashboard_menu == page
  end

  def abc
    ABC
  end

  def formatted_date(date)
    date.strftime('%Y-%m-%d')
  end

  def formatted_datetime(datetime)
    datetime.strftime('%Y-%m-%dT%H:%M')
  end

  def user_amount
    return unless user_signed_in?

    {
      products: current_user.products.size,
      bookmarks: Bookmark.where(user_id: current_user.id).size,
      setups: current_user.setups.size
    }
  end
end
