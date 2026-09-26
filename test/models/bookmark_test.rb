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

  test 'bookmark_list of another user is invalid' do
    bookmark = bookmarks(:with_product)
    bookmark.bookmark_list = bookmark_lists(:other_user)

    assert_not bookmark.valid?
    assert bookmark.errors[:bookmark_list].any?
  end

  test 'bookmark_list of the same user is valid' do
    bookmark = bookmarks(:with_product_variant)
    bookmark.bookmark_list = bookmark_lists(:two)

    assert bookmark.valid?
  end

  test 'a new bookmark_list cannot take the bookmarks of another user' do
    bookmark_list = users(:one).bookmark_lists.new(
      name: 'Taken',
      bookmark_ids: [bookmarks(:with_past_event).id]
    )

    assert_not bookmark_list.save
    assert_nil bookmarks(:with_past_event).reload.bookmark_list_id
  end

  test 'associations' do
    bookmark = Bookmark.first
    assert_respond_to bookmark, :user
    assert_respond_to bookmark, :item
    assert_respond_to bookmark, :bookmark_list
  end
end
