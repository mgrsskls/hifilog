class SearchController < ApplicationController
  add_breadcrumb I18n.t('search')

  def results
    @query = params[:query].strip

    if params[:query].length < 3
      flash.now[:alert] = 'Please enter at least 3 characters.'
    else
      query = "%#{params[:query]}%"

      @products = Product.where('name ILIKE ?', query).includes([:brand, :sub_categories])
                         .sort_by { |a| -(query.length - a.name.length) }
      @brands = Brand.where('name ILIKE ?', query).includes([:products])
                     .sort_by { |a| -(query.length - a.name.length) }
    end
  end
end
