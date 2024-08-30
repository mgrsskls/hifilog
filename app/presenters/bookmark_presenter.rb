class BookmarkPresenter < ItemPresenter
  def delete_path
    bookmark_path(@object.id)
  end

  def delete_button_label
    I18n.t('bookmark.remove.label')
  end

  def delete_confirm_msg
    I18n.t('bookmark.remove.confirm', name: display_name)
  end

  def product_option
    nil
  end
end
