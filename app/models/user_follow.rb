# frozen_string_literal: true

class UserFollow < ApplicationRecord
  belongs_to :follower, class_name: 'User'
  belongs_to :followed, class_name: 'User'

  validates :followed_id, uniqueness: { scope: :follower_id }
  validate :cannot_follow_self
  validate :cannot_follow_blocked_user

  after_commit :record_followed_by_user_activity, on: :create
  after_commit :notify_followed_user, on: :create
  after_destroy_commit :hide_followed_by_user_activity

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at followed_id follower_id id id_value updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[followed follower]
  end
  # :nocov:

  private

  def record_followed_by_user_activity
    UserActivities::Recorder.followed_by_user(self)
  end

  def notify_followed_user
    return unless followed.receives_follow_notifications?
    return if follower_previously_notified?

    UserMailer.followed_notification(self).deliver_later
  end

  # Notify at most once per follower/followed pair, so follow/unfollow
  # toggling cannot be used to spam the followed user's inbox. Earlier
  # followed_by_user activities (including ones hidden by an unfollow) serve
  # as the record of past notifications.
  def follower_previously_notified?
    # followed_by_user activities always have a UserFollow subject; excluding
    # this follow's id keeps the check independent of after_commit ordering.
    UserActivity.where(user_id: followed_id, verb: 'followed_by_user')
                .where("metadata ->> 'follower_id' = ?", follower_id.to_s)
                .where.not(subject_id: id)
                .exists?
  end

  def hide_followed_by_user_activity
    UserActivities::Recorder.hide_followed_by_user(self)
  end

  def cannot_follow_self
    return unless follower_id.present? && follower_id == followed_id

    errors.add(:followed, :invalid)
  end

  def cannot_follow_blocked_user
    return unless follower && followed

    errors.add(:followed, :blocked) if followed.blocks?(follower)
  end
end
