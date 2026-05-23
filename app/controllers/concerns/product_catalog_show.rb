# frozen_string_literal: true

module ProductCatalogShow
  extend ActiveSupport::Concern

  private

  def assign_product_catalog_show_data(product:, product_variant: nil)
    data = ProductCatalogShowService.new(
      product:,
      product_variant:,
      current_user: user_signed_in? ? current_user : nil
    ).call

    @images = data.fetch(:images)
    @contributors = data.fetch(:contributors)
    @custom_attributes = data[:custom_attributes]

    return unless user_signed_in?

    @possessions = data.fetch(:possessions)
    @bookmark = data[:bookmark]
    @note = data[:note]
    @setups = data.fetch(:setups)
  end
end
