class ItemPresenter
  include Rails.application.routes.url_helpers

  delegate_missing_to :@object

  attr_reader :object, :product, :product_variant

  delegate :name, to: :brand, prefix: true

  def initialize(object, type = nil)
    @object = object

    if type.present?
      if type == :product
        @product = object.product
      elsif type == :product_variant
        @product = object.product
        @product_variant = object.product_variant
      end
    else
      @product = object.product
      @product_variant = object.product_variant
    end
  end

  def short_name
    return @product_variant.short_name if @product_variant.present?

    @product.name
  end

  def display_name
    return @product_variant.display_name if @product_variant.present?

    @product.display_name
  end

  def release_date
    return @product_variant.release_date if @product_variant.present?

    @product.release_date
  end

  # def product_options
  #   return @product_variant.product_options if @product_variant.present?

  #   @product.product_options
  # end

  def show_path
    return @product_variant.path if @product_variant.present?

    product_path(id: @product.friendly_id)
  end

  def edit_path
    if @product_variant.present?
      return product_edit_variant_path(product_id: @product.friendly_id, variant: @product_variant.friendly_id)
    end

    edit_product_path(id: @product.friendly_id)
  end

  def update_path
    possession_path(id: @object.id)
  end

  def delete_path
    possession_path(id: @object.id)
  end

  def delete_button_label
    I18n.t('remove_product.label')
  end

  def delete_confirm_msg
    I18n.t('remove_product.confirm', name: display_name)
  end

  def brand
    @product.brand
  end

  def categories
    @product.categories
  end

  def sub_categories
    @product.sub_categories
  end
end
