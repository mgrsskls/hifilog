# frozen_string_literal: true

class Setup < ApplicationRecord
  extend FriendlyId

  belongs_to :user, optional: true
  has_many :setup_possessions, dependent: :destroy
  has_many :possessions, through: :setup_possessions

  friendly_id :name, use: [:slugged, :scoped, :history], scope: :user_id

  before_destroy :snapshot_user_activities_metadata
  after_commit :record_setup_created_user_activity, on: :create
  after_commit :record_setup_visibility_change_user_activity, on: :update

  auto_strip_attributes :name, squish: true

  validates :name, presence: true, uniqueness: { scope: :user }
  validates :slug, presence: true, uniqueness: { scope: :user_id }
  validates :private, inclusion: { in: [true, false], message: I18n.t('setup.validation.private.selected') }
  validates :user, presence: true

  def visibility
    private? ? I18n.t('setup.private_values.yes') : I18n.t('setup.private_values.no')
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      user_id
      user_id_eq
      created_at_gteq
      created_at_lteq
      updated_at_gteq
      updated_at_lteq
      slugs_id_eq
      slug
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # :nocov:

  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end

  private

  def record_setup_created_user_activity
    UserActivities::Recorder.setup_created(self)
  end

  def record_setup_visibility_change_user_activity
    old_private, new_private = saved_change_to_private
    return if old_private.nil?

    if old_private == true && new_private == false
      UserActivities::Recorder.setup_made_public(self)
    elsif old_private == false && new_private == true
      UserActivities::Recorder.setup_made_private(self)
    end
  end

  def snapshot_user_activities_metadata
    return unless user

    meta = UserActivities::Recorder.setup_metadata(self).stringify_keys
    user.user_activities.where(subject: self).find_each do |activity|
      activity.update!(metadata: activity.metadata.merge(meta), updated_at: Time.current)
    end
  end
end
