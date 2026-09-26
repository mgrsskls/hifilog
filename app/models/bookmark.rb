# frozen_string_literal: true

class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :item, polymorphic: true
  belongs_to :bookmark_list, optional: true

  validates :item_id, uniqueness: { scope: [:user_id, :item_type] }
  validate :bookmark_list_belongs_to_user

  # simplecov:disable
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      bookmark_list_id_eq
      created_at
      id
      id_value
      updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # simplecov:enable

  private

  # A list holds only the bookmarks of its own user (docs/collection.md#4-bookmark).
  # BookmarkListsController drops the bookmark ids of other users already; this check also covers
  # the console and ActiveAdmin.
  def bookmark_list_belongs_to_user
    return if bookmark_list.blank?
    return if bookmark_list.user_id == user_id

    errors.add(:bookmark_list, :invalid)
  end
end
