class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :item, polymorphic: true
  belongs_to :bookmark_list, optional: true

  validates :item_id, uniqueness: { scope: [:user_id, :item_type] }

  # :nocov:
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
  # :nocov:
end
