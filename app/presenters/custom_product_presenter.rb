class CustomProductPresenter
  include Rails.application.routes.url_helpers

  delegate_missing_to :@custom_product

  def initialize(object)
    @custom_product = object
  end

  delegate :image, to: :@custom_product

  def diy_kit?
    false
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

  def sorted_images
    @custom_product.images.sort_by { |image| @custom_product.highlighted_image_id == image.id ? 0 : 1 }
  end

  def highlighted_image
    if @custom_product.images.attached?
      if @custom_product.highlighted_image_id &&
         @custom_product.images.find_by(id: @custom_product.highlighted_image_id)
        return @custom_product.images.find_by(id: @custom_product.highlighted_image_id)
      end

      return @custom_product.images.first
    end

    nil
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
