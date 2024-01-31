class FeedController < ApplicationController
  def rss
    products = Product.includes([:brand]).order(created_at: :desc).limit(10)
    brands = Brand.order(created_at: :desc).limit(10)

    @all = (products + brands).sort_by(&:created_at)

    respond_to do |format|
      format.rss { render layout: false }
    end
  end
end
