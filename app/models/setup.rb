class Setup < ApplicationRecord
  belongs_to :user, optional: true
  has_many :setup_possessions, dependent: :destroy
  has_many :possessions, through: :setup_possessions

  auto_strip_attributes :name, squish: true

  validates :name, presence: true, uniqueness: { scope: :user }
  validates :private, inclusion: { in: [true, false], message: 'must be selected' }
  validates :user, presence: true

  def visibility
    private? ? I18n.t('setup.private_values.yes') : I18n.t('setup.private_values.no')
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      user_id
      user_id_eq
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
end
