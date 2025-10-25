class BookmarkPresenter
  include Rails.application.routes.url_helpers

  delegate_missing_to :@object

  attr_reader :product, :product_variant

  def initialize(object)
    @object = object

    if object.item_type == 'ProductVariant'
      @product_variant = object.item
      @product = object.item.product
    elsif object.item_type == 'Product'
      @product = object.item
    end
  end

  def display_name
    return @product.display_name if @product.present?
    return @product_variant.display_name if @product_variant.present?

    nil
  end

  def delete_path
    bookmark_path(@object.id)
  end

  def delete_button_label
    I18n.t('bookmark.remove.label')
  end

  def delete_confirm_msg
    I18n.t('bookmark.remove.confirm', name: display_name)
  end
end
