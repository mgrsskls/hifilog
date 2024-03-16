class Setup < ApplicationRecord
  belongs_to :user, optional: true
  has_many :setup_possessions, dependent: :destroy
  has_many :possessions, through: :setup_possessions

  validates :name, presence: true, uniqueness: { scope: :user, case_sensitive: false }
  validates :private, inclusion: { in: [true, false], message: 'must be selected' }

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      id
      name
      private
      setup_possessions_id
      setup_possessions_possession_id
      updated_at
      user_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[possessions user]
  end
end
