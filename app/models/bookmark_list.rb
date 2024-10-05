class BookmarkList < ApplicationRecord
  belongs_to :user
  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :bookmarks
  # rubocop:enable Rails/HasManyOrHasOneDependent

  validates :name, presence: true, uniqueness: { scope: :user_id }

  # :nocov:
  def self.ransackable_associations(_auth_object = nil)
    %w[bookmarks user]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id id_value name updated_at user_id]
  end
  # :nocov:
end
