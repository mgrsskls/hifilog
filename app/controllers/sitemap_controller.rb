class SitemapController < ApplicationController
  skip_after_action :record_page_view

  def xml
    map = XmlSitemap::Map.new('www.hifilog.com', secure: true) do |m|
      m.add users_path
      User.where(profile_visibility: 2).find_each do |user|
        m.add user_path(user.user_name.downcase)
      end

      m.add changelog_path
      m.add about_path
      m.add calculators_root_path
      m.add calculators_resistors_for_amplifier_to_headphone_adapter_path

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
      ProductVariant.includes([product: [:brand]]).find_each do |product_variant|
        m.add product_variant.path, updated: product_variant.updated_at
      end
    end

    render xml: map.render
  end
end
