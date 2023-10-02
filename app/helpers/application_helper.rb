module ApplicationHelper
  def is_current_page?(test_path)
    return request.path == test_path
  end

  def active_menu_state(page)
    return ' aria-current="page"'.html_safe if @active_menu == page
  end
end
