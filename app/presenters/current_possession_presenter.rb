class CurrentPossessionPresenter < PossessionPresenter
  def delete_button_label
    I18n.t('remove_product.label')
  end

  def delete_confirm_msg
    I18n.t('remove_product.confirm', name: @object.display_name)
  end
end
