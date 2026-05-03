# frozen_string_literal: true

require 'stringio'
require 'test_helper'

class ProductItemPresenterTest < ActiveSupport::TestCase
  ONE_BY_ONE_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ).freeze

  setup do
    @product = products(:one)
    @item = product_item_for(@product)
  end

  test 'list_highlighted_image is nil when no possession has images' do
    presenter = ProductItemPresenter.new(@item, true)
    assert_nil presenter.list_highlighted_image
  end

  test 'list_highlighted_image returns highlighted attachment when a visible possession has images' do
    possession = possessions(:current_product)
    attach_png(possession)

    presenter = ProductItemPresenter.new(reload_item, true)
    attachment = presenter.list_highlighted_image

    assert attachment
    assert_equal 'image/png', attachment.blob.content_type
  end

  test 'earliest qualifying possession wins' do
    older = possessions(:current_product)
    attach_png(older)
    older.update_column(:created_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations

    newer = Possession.create!(
      product: @product,
      user: users(:visible),
      period_from: Time.zone.today,
      prev_owned: false
    )
    attach_png(newer)
    newer.update_column(:created_at, 1.day.ago) # rubocop:disable Rails/SkipsModelValidations

    presenter = ProductItemPresenter.new(reload_item, true)
    attachment = presenter.list_highlighted_image

    assert attachment
    assert_includes older.images, attachment
  end

  test 'guest does not see images from logged_in_only profiles' do
    possession = possessions(:current_product)
    possession.update!(user: users(:logged_in_only))
    attach_png(possession)

    guest = ProductItemPresenter.new(reload_item, false)
    assert_nil guest.list_highlighted_image

    signed_in = ProductItemPresenter.new(reload_item, true)
    assert signed_in.list_highlighted_image
  end

  test 'base product row includes possessions linked only to a variant' do
    @product = products(:with_variants)
    possession = possessions(:current_product_variant)
    possession.update_column(:product_id, nil) # rubocop:disable Rails/SkipsModelValidations
    attach_png(possession)

    presenter = ProductItemPresenter.new(reload_item, true)
    attachment = presenter.list_highlighted_image

    assert attachment
    assert_includes possession.reload.images, attachment
  end

  test 'list_highlighted_image for ProductVariant row uses variant possessions' do
    variant = product_variants(:one)
    possession = Possession.create!(
      product: variant.product,
      product_variant: variant,
      user: users(:one),
      period_from: Time.zone.today,
      prev_owned: false
    )
    attach_png(possession)

    item = ProductItem.preload_list_possession_images(
      ProductItem.where(item_type: 'ProductVariant', product_variant_id: variant.id)
    ).first!

    presenter = ProductItemPresenter.new(item, true)
    attachment = presenter.list_highlighted_image

    assert attachment
    assert_includes possession.reload.images, attachment
  end

  private

  def attach_png(possession)
    possession.images.attach(
      io: StringIO.new(ONE_BY_ONE_PNG),
      filename: 'x.png',
      content_type: 'image/png'
    )
  end

  def product_item_for(product)
    ProductItem.preload_list_possession_images(
      ProductItem.where(product_id: product.id, item_type: 'Product')
    ).first!
  end

  def reload_item
    product_item_for(@product)
  end
end
