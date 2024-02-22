module BrandHelper
  def all_sub_categories_for(brand)
    (
      brand.sub_categories.includes([:sub_categories]) +
      SubCategory.joins(:products).where(products: brand.products).order(:name).distinct
    ).uniq.sort_by(&:name)
  end
end
