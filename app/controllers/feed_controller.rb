class FeedController < ApplicationController
  def rss
    products = Product.all.includes([:brand])
    brands = Brand.all

    @all = (products + brands).sort_by(&:created_at)

    respond_to do |format|
      format.rss { render layout: false }
    end
  end
end
