class SitemapController < ApplicationController
  def xml
    map = XmlSitemap::Map.new('www.hifilog.com', secure: true) do |m|
      m.add brands_path
      Brand.find_each do |brand|
        m.add brand_path(brand)
      end

      m.add categories_path
      Category.find_each do |category|
        m.add category_path(category)
      end

      m.add products_path
      Product.includes([:brand]).find_each do |product|
        m.add product_path(
          id: product.friendly_id,
        ), updated: product.updated_at
      end

      SubCategory.includes([:category]).find_each do |sub_category|
        m.add category_sub_category_path(id: sub_category.friendly_id, category_id: sub_category.category.friendly_id)
      end
    end

    render xml: map.render
  end
end
