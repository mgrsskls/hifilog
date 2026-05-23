# frozen_string_literal: true

require 'test_helper'

class ProductCatalogShowServiceTest < ActiveSupport::TestCase
  test 'product show data scopes possessions to base product rows' do
    product = products(:one)
    user = users(:one)

    data = ProductCatalogShowService.new(product:, current_user: user).call

    assert(data.fetch(:possessions).all? { |p| p.object.product_variant_id.nil? })
    assert_kind_of ActiveRecord::Result, data.fetch(:contributors)
    assert_kind_of Array, data.fetch(:images)
  end

  test 'variant show data scopes possessions to the variant' do
    product = products(:with_variants)
    variant = product_variants(:one)
    user = users(:one)

    data = ProductCatalogShowService.new(
      product:,
      product_variant: variant,
      current_user: user
    ).call

    assert(data.fetch(:possessions).all? { |p| p.object.product_variant_id == variant.id })
  end

  test 'guest receives images and contributors without signed-in sidebar data' do
    product = products(:one)

    data = ProductCatalogShowService.new(product:).call

    assert_not data.key?(:possessions)
    assert_kind_of Array, data.fetch(:images)
    assert_kind_of ActiveRecord::Result, data.fetch(:contributors)
  end

  test 'custom attributes use product custom_attributes_resources' do
    product = products(:with_custom_attributes)

    data = ProductCatalogShowService.new(product:).call

    assert_equal product.custom_attributes_resources, data.fetch(:custom_attributes)
  end

  test 'community gallery only includes possessions with attached images' do
    product = products(:one)
    visible_user = users(:one)
    possession = possessions(:current_product)
    possession.update!(images: [one_by_one_png_upload(filename: 'gallery.png')])

    images = ProductCatalogShowService.new(product:, current_user: visible_user).call.fetch(:images)

    assert(images.any? { |image| image.user.id == visible_user.id })

    possession.images.purge

    images_after_purge = ProductCatalogShowService.new(product:, current_user: visible_user).call.fetch(:images)

    assert_empty(images_after_purge.select { |image| image.user.id == visible_user.id })
  end
end
