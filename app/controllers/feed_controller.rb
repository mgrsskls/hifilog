class FeedController < ApplicationController
  def rss
    @all = (newest_products + newest_brands).sort_by(&:created_at).reverse!

    respond_to do |format|
      format.rss { render layout: false }
    end
  end
end
