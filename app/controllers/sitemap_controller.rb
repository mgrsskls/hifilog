class SitemapController < ApplicationController
  def xml
    map = XmlSitemap::Map.new('www.hifilog.com', secure: true) do |m|
      m.add brands_path
      Brand.find_each do |brand|
        m.add brand_path(brand)
      end

      m.add products_path
      Product.includes([:brand]).find_each do |product|
        m.add product_path(
          id: product.friendly_id,
        ), updated: product.updated_at
      end
    end

    render xml: map.render
  end
end
