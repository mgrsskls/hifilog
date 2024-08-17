class CustomProductPossessionPresenter < CustomProductPresenter
  include Rails.application.routes.url_helpers

  delegate_missing_to :@object

  def initialize(object)
    super

    @object = object
    @custom_product = object.custom_product
  end

  def image_update_item
    @custom_product
  end

  def delete_path
    possession_path(@object.id)
  end

  def delete_button_label
    I18n.t('remove_product_from_prev_owneds.label')
  end

  def delete_confirm_msg
    I18n.t('remove_product_from_prev_owneds.confirm', name: display_name)
  end

  def setup
    @object.setup
  end

  def prev_owned
    @object.prev_owned
  end
end
