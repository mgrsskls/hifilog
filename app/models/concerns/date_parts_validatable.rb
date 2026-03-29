# frozen_string_literal: true

module DatePartsValidatable
  extend ActiveSupport::Concern

  class_methods do
    def validates_release_date_parts
      validates :release_day,
                numericality: { only_integer: true },
                comparison: { greater_than: 0, less_than: 32 },
                if: -> { release_day.present? }

      validates :release_month,
                numericality: { only_integer: true },
                comparison: { greater_than: 0, less_than: 13 },
                if: -> { release_month.present? }

      validates :release_year,
                numericality: { only_integer: true },
                comparison: { greater_than: 1899 },
                if: -> { release_year.present? }
    end
  end
end
