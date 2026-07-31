# frozen_string_literal: true

require 'test_helper'

class UserImagesQueryTest < ActiveSupport::TestCase
  test 'returns possession rows with all images' do
    user = users(:without_anything)
    possession = Possession.create!(user: user, product: products(:one), prev_owned: false)
    possession.update!(
      images: [
        one_by_one_png_upload(filename: 'possession-a.png'),
        one_by_one_png_upload(filename: 'possession-b.png')
      ]
    )

    rows = UserImagesQuery.call(page: 1)
    possession_row = rows.find { |row| row.type == 'possession' && row.record.id == possession.id }

    assert possession_row
    assert_equal user, possession_row.user
    assert_equal 2, possession_row.images.size
  end

  test 'returns avatar and decorative image rows' do
    user = users(:without_anything)
    user.update!(avatar: one_by_one_png_upload(filename: 'avatar.png'))
    user.update!(decorative_image: one_by_one_png_upload(filename: 'header.png'))

    rows = UserImagesQuery.call(page: 1)
    types_for_user = rows.select { |row| row.user.id == user.id }.map(&:type)

    assert_includes types_for_user, 'avatar'
    assert_includes types_for_user, 'decorative_image'
  end
end
