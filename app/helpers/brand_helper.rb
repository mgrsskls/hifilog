# frozen_string_literal: true

module BrandHelper
  def brand_products_path_with_filter(brand, category, sub_category, products = {})
    params = if sub_category.present?
               {
                 brand_id: brand.friendly_id,
                 category: sub_category.present? ? "#{category.friendly_id}[#{sub_category.friendly_id}]" : nil
               }.merge(products)
             else
               {
                 brand_id: brand.friendly_id,
                 category: category&.friendly_id
               }.merge(products)
             end

    brand_products_path(**params)
  end
end
