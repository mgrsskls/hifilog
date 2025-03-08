class CustomProductPresenter
  include Rails.application.routes.url_helpers

  delegate_missing_to :@custom_product

  def initialize(object)
    @custom_product = object
  end

  def short_name
    @custom_product.name
  end

  def display_name
    @custom_product.name
  end

  def release_date
    nil
  end

  def show_path
    user_custom_product_path(id: @custom_product.id, user_id: user.user_name.downcase)
  end

  def edit_path
    dashboard_edit_custom_product_path(id: @custom_product.id)
  end

  def update_path
    custom_product_path(id: @custom_product.id)
  end

  def delete_path
    custom_product_path(id: @custom_product.id)
  end

  def delete_button_label
    I18n.t('custom_product.delete.label')
  end

  def delete_confirm_msg
    I18n.t('custom_product.delete.confirm', name:)
  end

  def image_update_item
    @custom_product
  end

  def brand_name
    'Custom'
  end

  def categories
    sub_categories.map(&:category).uniq
  end

  delegate :sub_categories, to: :@custom_product

  def product_variant
    nil
  end

  def prev_owned
    false
  end

  def setup
    false
  end

  def product_option
    nil
  end
end
