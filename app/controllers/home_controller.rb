# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    return redirect_to dashboard_root_path if user_signed_in?

    @brand_countries = brand_countries
    assign_highlights
  end

  private

  # The live blocks of the page. Every one of them may legitimately come back empty -- a fresh
  # database, no public photos, nothing upcoming -- and the view then skips that section instead
  # of rendering an empty heading.
  def assign_highlights
    @just_added = HomeHighlights.just_added
    @events, @event_attendee_counts = HomeHighlights.upcoming_events
    @totals = HomeHighlights.totals.select { |_key, value| value.to_i.positive? }
  end

  def brand_countries
    Brand
      .group(:country_code)
      .order('COUNT(country_code) DESC')
      .limit(5)
      .count
      .map do |country|
        country_code = country[0]
        {
          label: country_name_from_country_code(country_code),
          brands_path: brands_path({ brands: { country: country_code } }),
          products_path: products_path({ brands: { country: country_code } })
        }
      end
  end
end
