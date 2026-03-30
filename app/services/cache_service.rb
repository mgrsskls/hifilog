# frozen_string_literal: true

class CacheService
  def self.menu_categories
    Rails.cache.fetch('/menu_categories') do
      Category.includes(:sub_categories).group_by(&:column)
    end
  end

  def self.products_count
    Rails.cache.fetch('/product_count') do
      Product.count + ProductVariant.count
    end
  end

  def self.brands_count
    Rails.cache.fetch('/brands_count') do
      Brand.count
    end
  end

  def self.categories_count
    Rails.cache.fetch('/categories_count') do
      SubCategory.count
    end
  end

  def self.newest_products
    Rails.cache.fetch('/newest_products') do
      products = Product.includes([:brand]).order(created_at: :desc).limit(10)
      product_variants = ProductVariant.includes([{ product: [:brand] }]).order(created_at: :desc).limit(10)

      (products + product_variants).sort_by(&:created_at).reverse.take(10)
    end
  end

  def self.newest_brands
    Rails.cache.fetch('/newest_brands') do
      Brand.order(created_at: :desc).limit(10).to_a
    end
  end
end
