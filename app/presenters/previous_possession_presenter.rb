class PreviousPossessionPresenter < PossessionPresenter
  def delete_button_label
    I18n.t('product.remove_from_prev_owneds.label')
  end

  def delete_confirm_msg
    I18n.t('product.remove_from_prev_owneds.confirm', name: display_name)
  end
end
