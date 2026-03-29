# frozen_string_literal: true

require 'test_helper'

class BookmarkTest < ActiveSupport::TestCase
  test 'item_id uniqueness per user and item_type' do
    user = users(:one)
    bookmark1 = user.bookmarks.first
    bookmark2 = Bookmark.new(
      user_id: user.id,
      item_id: bookmark1.item_id,
      item_type: bookmark1.item_type
    )
    assert_not bookmark2.valid?
    assert bookmark2.errors[:item_id].any?
  end

  test 'same item can be bookmarked by different users' do
    product = products(:one)
    user1 = users(:one)
    user2 = users(:hidden)

    user1.bookmarks.find_by(item_id: product.id, item_type: 'Product')
    bookmark2 = Bookmark.new(
      user_id: user2.id,
      item_id: product.id,
      item_type: 'Product'
    )
    assert bookmark2.valid?
  end

  test 'associations' do
    bookmark = Bookmark.first
    assert_respond_to bookmark, :user
    assert_respond_to bookmark, :item
    assert_respond_to bookmark, :bookmark_list
  end
end
