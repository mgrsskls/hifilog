# frozen_string_literal: true

module ReleaseDate
  extend ActiveSupport::Concern

  include DateFromComponents

  def release_date
    date_from_components(release_year, release_month, release_day)
  end
end
