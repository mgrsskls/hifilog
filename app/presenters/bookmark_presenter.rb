# frozen_string_literal: true

class BookmarkPresenter
  include Rails.application.routes.url_helpers

  delegate_missing_to :@object

  attr_reader :product, :product_variant, :event, :brand

  def initialize(object)
    @object = object

    item = object.item

    case object.item_type
    when 'ProductVariant'
      @product_variant = item
      @product = item.product
    when 'Product'
      @product = item
    when 'Event'
      @event = item
    when 'Brand'
      @brand = item
    end
  end

  def type
    return Product.model_name.human(count: 1) if @product.present?
    return Brand.model_name.human(count: 1) if @brand.present?
    return Event.model_name.human(count: 1) if @event.present?

    nil
  end

  def discontinued?
    if @event.present?
      end_date = @event.end_date
      time_zone_today = Time.zone.today

      return time_zone_today > end_date if end_date.present?

      return time_zone_today > @event.start_date
    end

    return @product_variant.discontinued? if @product_variant.present?
    return @product.discontinued? if @product.present?

    @brand.presence&.discontinued?
  end

  def display_name
    return @product_variant.display_name if @product_variant.present?
    return @product.display_name if @product.present?
    return @brand.name if @brand.present?
    return @event.name if @event.present?

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
