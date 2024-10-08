class SetupPossessionPresenter < PossessionPresenter
  def initialize(object, setup)
    super(object)

    @setup = setup
  end

  def delete_path
    setup_possession_path(@object.setup_possession)
  end

  def delete_button_label
    I18n.t('product.remove_from_setup.label')
  end

  def delete_confirm_msg
    I18n.t('product.remove_from_setup.confirm', name: display_name)
  end
end
