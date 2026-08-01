# frozen_string_literal: true

class ProductItemPresenter
  include Rails.application.routes.url_helpers
  include FormatHelper

  delegate_missing_to :@object

  def initialize(object, user_signed_in)
    @object = object
    @user_signed_in = user_signed_in
  end

  # Only contribute_product_items carries a completeness score; the leaner product_items view
  # dropped it (and the LATERAL that computes it) so catalogue listings do not pay for it.
  # Returning nil rather than letting delegate_missing_to raise keeps shared/_product usable for
  # both, and shared/_entity_list_item only renders the bar when render_completeness is set.
  def completeness
    @object.completeness if @object.has_attribute?(:completeness)
  end

  def display_name
    return "#{@object.name} #{@object.variant_name}" if @object.item_type == 'ProductVariant'

    @object.name
  end

  def id
    return @object.product_variant_id if @object.item_type == 'ProductVariant'

    @object.product_id
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

  def list_highlighted_image
    possession = @object.earliest_list_possession_with_images(user_signed_in: @user_signed_in)
    return nil unless possession

    PossessionPresenter.new(possession).highlighted_image
  end
end
