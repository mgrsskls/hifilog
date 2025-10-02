module BrandHelper
  def brand_products_count(brand, category, sub_category, diy_kit, attr)
    if category.nil? && sub_category.nil? && diy_kit.nil? && attr.nil?
      return (brand.products_count.nil? ? 0 : brand.products_count)
    end

    products = brand.products

    if sub_category.present?
      products = products.joins(:sub_categories)
                         .where(sub_categories: sub_category.id)
    elsif category.present?
      products = products.joins(:sub_categories)
                         .where(sub_categories: { category_id: category.id })
    end

    if diy_kit.present?
      products = products.left_outer_joins(:product_variants)
      products = if diy_kit == '0'
                   products.where(product_variants: { diy_kit: false })
                           .or(products.where(diy_kit: false))
                 else
                   products.where(product_variants: { diy_kit: true })
                           .or(products.where(diy_kit: true))
                 end
    end

    if attr.present?
      CustomAttribute.find_each do |custom_attribute|
        id_s = custom_attribute.id.to_s
        if attr[id_s].present?
          products = products.where('custom_attributes ->> ? IN (?)', id_s, attr[custom_attribute.id.to_s])
        end
      end
    end

    products.distinct.size
  end

  def brand_products_path_with_filter(brand, category, sub_category, products = {})
    params = if sub_category.present?
               {
                 brand_id: brand.friendly_id,
                 category: sub_category.present? ? "#{category.friendly_id}[#{sub_category.friendly_id}]" : nil,
               }.merge(products)
             else
               {
                 brand_id: brand.friendly_id,
                 category: category&.friendly_id,
               }.merge(products)
             end

    brand_products_path(**params)
  end
end
