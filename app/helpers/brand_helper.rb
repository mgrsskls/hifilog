module BrandHelper
  def all_sub_categories(brand)
    (
      brand.sub_categories +
      SubCategory.includes(:category).joins(:products).where(products: brand.products).order(:name).distinct
    ).uniq.sort_by(&:name)
  end
end
