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

  def current_user_products_count
    return unless user_signed_in?

    @current_user_products_count ||= current_user.products.count
  end

  def current_user_bookmarks_count
    return unless user_signed_in?

    @current_user_bookmarks_count ||= current_user.bookmarks.count
  end

  def current_user_setups_count
    return unless user_signed_in?

    @current_user_setups_count ||= current_user.setups.count
  end

  def rounddown(num)
    x = Math.log10(num).floor
    (num / (10.0**x)).floor * 10**x
  end
end
