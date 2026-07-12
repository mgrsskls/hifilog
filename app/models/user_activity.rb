# frozen_string_literal: true

class UserActivity < ApplicationRecord
  VERBS = %w[
    added_to_collection
    added_to_previous
    moved_to_previous
    event_attendance
    event_attendance_cancelled
    setup_created
    setup_made_public
    setup_made_private
    setup_product_added
    setup_product_removed
    custom_product_created
    possession_image_uploaded
    possession_image_deleted
    avatar_uploaded
    avatar_deleted
    decorative_image_uploaded
    decorative_image_deleted
    followed_by_user
  ].freeze

  # Shown on the dashboard activity feed only, not on public profiles.
  PRIVATE_FEED_VERBS = %w[followed_by_user].freeze

  # Persisted for auditing/admin but omitted when building the public profile feed.
  FEED_HIDDEN_VERBS = %w[
    setup_made_private
    possession_image_deleted
    avatar_uploaded
    avatar_deleted
    decorative_image_uploaded
    decorative_image_deleted
  ].freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true

  validates :verb, presence: true, inclusion: { in: VERBS }
  validates :occurred_at, presence: true

  scope :visible, -> { where(hidden_at: nil) }
  scope :for_feed, -> { where.not(verb: FEED_HIDDEN_VERBS) }
  scope :for_public_profile_feed, -> { for_feed.where.not(verb: PRIVATE_FEED_VERBS) }
  scope :chronological, -> { order(occurred_at: :desc) }

  def verb_sym
    verb.to_sym
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[subject user]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      hidden_at
      id
      metadata
      occurred_at
      subject_id
      subject_type
      updated_at
      user_id
      verb
    ]
  end
end
