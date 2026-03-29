# frozen_string_literal: true

module DateFromComponents
  extend ActiveSupport::Concern

  def date_from_components(year, month, day)
    return if year.blank?

    Date.new(year.to_i,
             month.present? ? month.to_i : 1,
             day.present? ? day.to_i : 1)
  end
end
