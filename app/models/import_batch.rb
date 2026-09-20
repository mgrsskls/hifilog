# frozen_string_literal: true

# One run of the importer.
#
# It exists for one question that is asked only when something has gone wrong:
# "where did these two thousand rows come from, and what else came with them?"
# A batch answers it, and makes the answer actionable -- every candidate of a
# run can be refused in one step.
class ImportBatch < ApplicationRecord
  has_many :import_candidates, dependent: :nullify

  validates :source, presence: true
  validates :started_at, presence: true

  scope :recent, -> { order(started_at: :desc) }

  def running? = finished_at.nil?

  def to_s = "#{source} #{started_at.to_date} (#{candidates_count})"

  def self.ransackable_associations(_auth_object = nil)
    ['import_candidates']
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[candidates_count created_at finished_at id id_value source started_at statistics
       tool_version updated_at]
  end
end
