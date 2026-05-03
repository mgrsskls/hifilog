# frozen_string_literal: true

require 'test_helper'

class ImagePresenterTest < ActiveSupport::TestCase
  ONE_BY_ONE_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ).freeze

  test 'exposes possessing user for Possession thumbnails' do
    possession = possessions(:current_product)
    possession.images.attach(
      io: StringIO.new(ONE_BY_ONE_PNG),
      filename: 't.png',
      content_type: 'image/png'
    )

    presenter = ImagePresenter.new(possession.images.first)

    assert_equal possession.user, presenter.user
  end

  test 'does not synthesize users outside possession attachments' do
    shim = Struct.new(:record_type, :record_id).new('CustomProduct', 1)

    assert_nil ImagePresenter.new(shim).user
  end
end
