class BookmarkPresenter
  include Rails.application.routes.url_helpers

  delegate_missing_to :@object

  attr_reader :product, :product_variant, :event

  def initialize(object)
    @object = object

    case object.item_type
    when 'ProductVariant'
      @product_variant = object.item
      @product = object.item.product
    when 'Product'
      @product = object.item
    when 'Event'
      @event = object.item
    end
  end

  def discontinued?
    if @event.present?
      return Time.zone.today > @event.end_date if @event.end_date.present?

      return Time.zone.today > @event.start_date
    end

    return @product_variant.discontinued? if @product_variant.present?

    @product.discontinued?
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
