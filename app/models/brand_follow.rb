# frozen_string_literal: true

# A user's subscription to a brand's new catalog entries.
#
# Deliberately thinner than +UserFollow+: a brand has no inbox and no block list, so there is no
# activity row, no notification mail and no generic-failure dance. The follow is public on both
# sides (the brand page lists followers, the profile lists followed brands) but it notifies
# nobody.
class BrandFollow < ApplicationRecord
  belongs_to :user
  belongs_to :brand

  validates :brand_id, uniqueness: { scope: :user_id }

  after_commit :flush_followers_count_cache, on: [:create, :destroy]

  # simplecov:disable
  def self.ransackable_attributes(_auth_object = nil)
    %w[brand_id created_at id id_value updated_at user_id]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[brand user]
  end
  # simplecov:enable

  private

  def flush_followers_count_cache
    Brand.flush_followers_count_cache(brand_id)
  end
end
