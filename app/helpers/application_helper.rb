module ApplicationHelper
  def is_current_page?(test_path)
    return request.path == test_path
  end

  def active_menu_state(page)
    return ' aria-current="true"'.html_safe if @active_menu == page
  end

  def active_dashboard_menu_state(page)
    return ' aria-current="true"'.html_safe if @active_dashboard_menu == page
  end

  def abc
    ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z']
  end
end
