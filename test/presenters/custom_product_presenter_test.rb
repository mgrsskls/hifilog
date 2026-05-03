# frozen_string_literal: true

require 'test_helper'

require 'base64'

class CustomProductPresenterTest < ActiveSupport::TestCase
  test 'surfaces custom branding copy and routed ownership paths' do
    presenter = CustomProductPresenter.new(custom_products(:one))

    assert_equal 'Custom', presenter.brand_name
    assert_not_predicate presenter.categories, :empty?

    owner = presenter.user.user_name.downcase
    assert_includes presenter.edit_path, '/dashboard/custom-products'
    assert_includes presenter.show_path, owner
    assert_includes presenter.show_path, custom_products(:one).id.to_s
  end

  test 'sorted images hoist highlighted uploads before the remainder' do
    custom_product = custom_products(:one)
    pixel_png = Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )

    custom_product.images.purge if custom_product.images.attached?
    custom_product.images.attach(
      io: StringIO.new(pixel_png),
      filename: 'cover.png',
      content_type: 'image/png'
    )
    custom_product.images.attach(
      io: StringIO.new(pixel_png),
      filename: 'detail.png',
      content_type: 'image/png'
    )

    primary, secondary = custom_product.images.order(:id).first(2)
    custom_product.update!(highlighted_image_id: secondary.id)

    presenter = CustomProductPresenter.new(custom_product)
    ordered_ids = presenter.sorted_images.map(&:id)

    assert_equal secondary.id, ordered_ids.first
    assert_equal primary.id, ordered_ids.second
    assert_equal secondary.id, presenter.highlighted_image.id

    assert_equal custom_product, presenter.image_update_item
    assert_nil presenter.product_variant
    assert_predicate presenter.delete_confirm_msg, :present?
  ensure
    custom_product&.images&.purge
    custom_product&.update!(highlighted_image_id: nil)
  end
end
