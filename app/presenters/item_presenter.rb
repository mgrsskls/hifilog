class ItemPresenter
  include Rails.application.routes.url_helpers

  delegate_missing_to :@object

  attr_reader :object, :product, :product_variant

  def initialize(object)
    @object = object
    @product = object.product
    @product_variant = object.product_variant
  end

  def short_name
    return @product_variant.short_name if @product_variant.present?

    @product.name
  end

  def display_name
    return @product_variant.display_name if @product_variant.present?

    @product.display_name
  end

  def product_or_variant_path
    return @product_variant.path if @product_variant.present?

    product_path(id: @product.friendly_id)
  end
end
