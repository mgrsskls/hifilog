class CustomProductSetupPossessionPresenter < CustomProductPossessionPresenter
  def initialize(object, setup)
    super(object)

    @setup = setup
  end

  def delete_path
    setup_possession_path(SetupPossession.find_by(possession_id: @object.id, setup_id: @setup.id))
  end

  def delete_button_label
    I18n.t('product.remove_from_setup.label')
  end

  def delete_confirm_msg
    I18n.t('product.remove_from_setup.confirm', name: display_name)
  end
end
