class CustomProductPresenter
  include Rails.application.routes.url_helpers

  delegate_missing_to :@object

  attr_reader :object, :custom_product

  def initialize(object)
    @object = object
    @custom_product = object.custom_product
  end

  def name
    @custom_product.name
  end

  def short_name
    name
  end

  def display_name
    name
  end

  def show_path
    user_custom_product_path(id: @custom_product.id, user_id: user.user_name.downcase)
  end

  def edit_path
    dashboard_edit_custom_product_path(id: @custom_product.id)
  end

  def delete_path
    custom_product_path(id: @custom_product.id)
  end

  def delete_button_label
    I18n.t('delete_custom_product.label')
  end

  def delete_confirm_msg
    I18n.t('delete_custom_product.confirm', name:)
  end

  def brand_name
    'Custom'
  end

  def categories
    sub_categories.map(&:category).uniq
  end

  def sub_categories
    @custom_product.sub_categories
  end
end
