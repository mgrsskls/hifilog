# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'profile_path' do
    assert_equal users(:visible).profile_path, '/users/username3'
  end

  test 'validations' do
    user = User.new
    assert_not user.valid?
    assert user.errors[:email].any?
    assert user.errors[:user_name].any?
  end

  test 'email uniqueness validation' do
    user = users(:one)
    duplicate = User.new(email: user.email, user_name: 'different_username')
    assert_not duplicate.valid?
    assert duplicate.errors[:email].any?
  end

  test 'email uniqueness case insensitive' do
    user = users(:one)
    duplicate = User.new(email: user.email.upcase, user_name: 'different_username')
    assert_not duplicate.valid?
  end

  test 'user_name uniqueness validation' do
    user = users(:one)
    duplicate = User.new(email: 'different@email.com', user_name: user.user_name)
    assert_not duplicate.valid?
    assert duplicate.errors[:user_name].any?
  end

  test 'user_name uniqueness case insensitive' do
    user = users(:one)
    duplicate = User.new(email: 'different@email.com', user_name: user.user_name.upcase)
    assert_not duplicate.valid?
  end

  test 'profile_visibility enum' do
    user = users(:one)
    user.profile_visibility = :hidden
    assert user.hidden?

    user.profile_visibility = :logged_in_only
    assert user.logged_in_only?

    user.profile_visibility = :visible
    assert user.visible?
  end

  test 'associations' do
    user = users(:one)
    assert_respond_to user, :possessions
    assert_respond_to user, :products
    assert_respond_to user, :setups
    assert_respond_to user, :bookmarks
    assert_respond_to user, :custom_products
    assert_respond_to user, :notes
    assert_respond_to user, :events
  end

  test 'display_name' do
    user = users(:one)
    assert_equal user.email, user.display_name
  end

  test 'rejects non image avatar types on update validation' do
    user = users(:one)
    user.avatar.attach(
      io: StringIO.new('not an image'),
      filename: 'note.txt',
      content_type: 'text/plain'
    )

    assert_not user.valid?(:update)
    assert user.errors[:avatar_content_type].present?
  ensure
    user.avatar.purge if user.avatar.attached?
  end

  test 'rejects avatar files larger than five megabytes on update' do
    user = users(:one)
    user.avatar.attach(
      io: StringIO.new('a' * 5_000_001),
      filename: 'big.jpg',
      content_type: 'image/jpeg'
    )

    assert_not user.valid?(:update)
    assert user.errors[:avatar_file_size].present?
  ensure
    user.avatar.purge if user.avatar.attached?
  end

  test 'attaching avatar records avatar_uploaded activity' do
    user = users(:one)
    user.avatar.purge if user.avatar.attached?

    assert_difference(-> { UserActivity.where(verb: 'avatar_uploaded', subject: user).count }, 1) do
      user.update!(avatar: one_by_one_png_upload(filename: 'avatar.png'))
    end

    attachment_id = user.avatar.attachment.id
    act = UserActivity.find_by!(user: user, subject: user, verb: 'avatar_uploaded')
    assert_equal attachment_id, act.metadata['image_attachment_id'].to_i
  end

  test 'replacing avatar records avatar_deleted and avatar_uploaded activities' do
    user = users(:one)
    user.update!(avatar: one_by_one_png_upload(filename: 'first.png'))
    old_attachment_id = user.avatar.attachment.id
    UserActivity.where(user: user, subject: user, verb: %w[avatar_uploaded avatar_deleted]).delete_all

    assert_difference(-> { UserActivity.where(verb: 'avatar_deleted', subject: user).count }, 1) do
      assert_difference(-> { UserActivity.where(verb: 'avatar_uploaded', subject: user).count }, 1) do
        user.update!(avatar: one_by_one_png_upload(filename: 'second.png'))
      end
    end

    deleted = UserActivity.find_by!(user: user, subject: user, verb: 'avatar_deleted')
    assert_equal old_attachment_id, deleted.metadata['image_attachment_id'].to_i
    assert_not_equal old_attachment_id, user.avatar.attachment.id
  end

  test 'purge_avatar! records avatar_deleted activity' do
    user = users(:one)
    user.update!(avatar: one_by_one_png_upload(filename: 'remove.png'))
    attachment_id = user.avatar.attachment.id
    UserActivity.where(user: user, subject: user, verb: 'avatar_deleted').delete_all

    assert_difference(-> { UserActivity.where(verb: 'avatar_deleted', subject: user).count }, 1) do
      user.purge_avatar!
    end

    act = UserActivity.find_by!(user: user, subject: user, verb: 'avatar_deleted')
    assert_equal attachment_id, act.metadata['image_attachment_id'].to_i
    assert_not user.reload.avatar.attached?
  end

  test 'attaching decorative_image records decorative_image_uploaded activity' do
    user = users(:one)
    user.decorative_image.purge if user.decorative_image.attached?

    assert_difference(-> { UserActivity.where(verb: 'decorative_image_uploaded', subject: user).count }, 1) do
      user.update!(decorative_image: one_by_one_png_upload(filename: 'banner.png'))
    end

    attachment_id = user.decorative_image.attachment.id
    act = UserActivity.find_by!(user: user, subject: user, verb: 'decorative_image_uploaded')
    assert_equal attachment_id, act.metadata['image_attachment_id'].to_i
  end

  test 'purge_decorative_image! records decorative_image_deleted activity' do
    user = users(:one)
    user.update!(decorative_image: one_by_one_png_upload(filename: 'remove-banner.png'))
    attachment_id = user.decorative_image.attachment.id
    UserActivity.where(user: user, subject: user, verb: 'decorative_image_deleted').delete_all

    assert_difference(-> { UserActivity.where(verb: 'decorative_image_deleted', subject: user).count }, 1) do
      user.purge_decorative_image!
    end

    act = UserActivity.find_by!(user: user, subject: user, verb: 'decorative_image_deleted')
    assert_equal attachment_id, act.metadata['image_attachment_id'].to_i
    assert_not user.reload.decorative_image.attached?
  end

  test 'rejects non image decorative uploads on update validation' do
    user = users(:one)
    user.decorative_image.attach(
      io: StringIO.new('not an image'),
      filename: 'banner.txt',
      content_type: 'text/plain'
    )

    assert_not user.valid?(:update)
    assert user.errors[:decorative_image_content_type].present?
  ensure
    user.decorative_image.purge if user.decorative_image.attached?
  end
end
