# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    redirect_to dashboard_root_path if user_signed_in?

    @brand_countries = Brand
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
