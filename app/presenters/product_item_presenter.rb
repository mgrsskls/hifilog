class ProductItemPresenter
  include Rails.application.routes.url_helpers
  include FormatHelper
  delegate_missing_to :@object

  def initialize(object)
    @object = object
  end

  def path
    if @object.item_type == 'ProductVariant'
      return product_variant_path(id: @object.variant_slug, product_id: @object.product_slug)
    end

    product_path(id: @object.product_slug)
  end

  def formatted_release_date
    format_partial_date(@object.release_year, @object.release_month, @object.release_day)
  end

  def formatted_discontinued_date
    format_partial_date(@object.discontinued_year, @object.discontinued_month, @object.discontinued_day)
  end
end
