class Setup < ApplicationRecord
  belongs_to :user, optional: true
  has_and_belongs_to_many :products

  validates :name, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      id
      name
      updated_at
      user_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[products user]
  end
end
