# frozen_string_literal: true

class UserBlock < ApplicationRecord
  belongs_to :blocker, class_name: 'User'
  belongs_to :blocked, class_name: 'User'

  validates :blocked_id, uniqueness: { scope: :blocker_id }
  validate :cannot_block_self

  after_create :remove_follow_relationships

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[blocked_id blocker_id created_at id id_value updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[blocked blocker]
  end
  # :nocov:

  private

  def remove_follow_relationships
    UserFollow.where(follower: blocked, followed: blocker).find_each(&:destroy)
    UserFollow.where(follower: blocker, followed: blocked).find_each(&:destroy)
  end

  def cannot_block_self
    return unless blocker_id.present? && blocker_id == blocked_id

    errors.add(:blocked, :invalid)
  end
end
