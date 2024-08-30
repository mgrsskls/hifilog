class CurrentPossessionPresenter < PossessionPresenter
  def delete_button_label
    I18n.t('product.remove.label')
  end

  def delete_confirm_msg
    I18n.t('product.remove.confirm', name: @object.display_name)
  end
end
