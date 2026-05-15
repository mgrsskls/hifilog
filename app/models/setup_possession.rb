# frozen_string_literal: true

class SetupPossession < ApplicationRecord
  belongs_to :setup
  belongs_to :possession

  validates :possession, uniqueness: true

  after_update :record_setup_product_moved_user_activity
  before_destroy :stash_setup_and_possession_for_setup_product_removed_activity
  after_commit :record_setup_product_added_user_activity, on: :create
  after_destroy_commit :record_setup_product_removed_user_activity

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      id
      id_value
      possession_id
      setup_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[
      possession
      setup
    ]
  end
  # :nocov:

  private

  def record_setup_product_added_user_activity
    UserActivities::Recorder.setup_product_added(self)
  end

  def record_setup_product_moved_user_activity
    change = saved_change_to_setup_id
    return unless change.is_a?(Array) && change.size == 2

    old_id, new_id = change
    return if old_id == new_id

    old_setup = Setup.find_by(id: old_id)
    if old_setup && old_setup.user_id == possession.user_id
      UserActivities::Recorder.setup_product_removed(
        user: possession.user,
        setup: old_setup,
        possession: possession
      )
    end
    UserActivities::Recorder.setup_product_added(self)
  end

  def stash_setup_and_possession_for_setup_product_removed_activity
    @stash_setup_for_removed_activity = setup
    @stash_possession_for_removed_activity = possession
  end

  def record_setup_product_removed_user_activity
    st = @stash_setup_for_removed_activity
    pos = @stash_possession_for_removed_activity
    return unless st && pos && st.user_id == pos.user_id

    UserActivities::Recorder.setup_product_removed(user: pos.user, setup: st, possession: pos)
  end
end
