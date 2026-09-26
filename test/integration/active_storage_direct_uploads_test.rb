# frozen_string_literal: true

require 'test_helper'

# The application uploads files only through its own forms. The direct upload endpoint of Active
# Storage needs no sign-in, so the application answers it with 404
# (docs/privacy-auth-security.md#3-security).
class ActiveStorageDirectUploadsTest < ActionDispatch::IntegrationTest
  BLOB_PARAMS = {
    blob: {
      filename: 'file.bin',
      byte_size: 4,
      checksum: Digest::MD5.base64digest('file'),
      content_type: 'application/octet-stream'
    }
  }.freeze

  ONE_BY_ONE_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ).freeze

  test 'a guest cannot create a blob' do
    assert_no_difference('ActiveStorage::Blob.count') do
      post rails_direct_uploads_path, params: BLOB_PARAMS, as: :json
    end

    assert_response :not_found
  end

  test 'a signed-in user cannot create a blob, also with a format suffix' do
    sign_in users(:one)

    [rails_direct_uploads_path, rails_direct_uploads_path(format: :json)].each do |path|
      assert_no_difference('ActiveStorage::Blob.count') do
        post path, params: BLOB_PARAMS, as: :json
      end

      assert_response :not_found, path
    end
  end

  test 'attached images are still served' do
    custom_product = custom_products(:one)
    custom_product.images.attach(io: StringIO.new(ONE_BY_ONE_PNG), filename: 'photo.png', content_type: 'image/png')

    get cdn_image_url(custom_product.images.first)

    assert_response :success
    assert_equal 'image/png', response.media_type
  end
end
