# frozen_string_literal: true

require 'test_helper'

class ImageTest < ActiveSupport::TestCase
  ONE_BY_ONE_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ).freeze

  test 'adds error when attachment content type is disallowed' do
    custom_product = custom_products(:one)
    custom_product.images.purge if custom_product.images.attached?
    custom_product.images.attach(
      io: StringIO.new('plain text'),
      filename: 'notes.txt',
      content_type: 'text/plain'
    )

    custom_product.validate(:update)

    assert custom_product.errors[:image_content_type].any?
  end

  test 'allows standard raster image types' do
    custom_product = custom_products(:one)
    custom_product.images.purge if custom_product.images.attached?
    custom_product.images.attach(
      io: StringIO.new(ONE_BY_ONE_PNG),
      filename: 'photo.png',
      content_type: 'image/png'
    )

    custom_product.validate(:update)

    assert_empty custom_product.errors[:image_content_type]
  end

  test 'flags oversized payloads' do
    custom_product = custom_products(:one)
    custom_product.images.purge if custom_product.images.attached?
    custom_product.images.attach(
      io: StringIO.new('x' * 10_000_001),
      filename: 'big.png',
      content_type: 'image/png'
    )

    custom_product.validate(:update)

    assert custom_product.errors[:image_file_size].any?
  end

  test 'mirrors validations on Possession updates' do
    possession = possessions(:current_product)
    possession.images.purge if possession.images.attached?
    possession.images.attach(
      io: StringIO.new('text'),
      filename: 'evil.exe',
      content_type: 'application/octet-stream'
    )

    possession.validate(:update)

    assert possession.errors[:image_content_type].any?
  end
end
