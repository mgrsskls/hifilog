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
      p_sql = Product.select("id, created_at, 'Product' as item_type").order(created_at: :desc).limit(10).to_sql
      v_sql = ProductVariant
              .select("id, created_at, 'ProductVariant' as item_type")
              .order(created_at: :desc).limit(10)
              .to_sql

      combined_sql = "(#{p_sql}) UNION (#{v_sql}) ORDER BY created_at DESC LIMIT 10"
      results = ActiveRecord::Base.connection.execute(combined_sql)

      results.group_by { |result| result['item_type'] }.flat_map do |type, rows|
        ids = rows.map { |result| result['id'] }
        if type == 'Product'
          Product
            .select(:created_at, :name, :slug, :model_no, :brand_id)
            .includes(:brand)
            .where(id: ids)
        else
          ProductVariant
            .select(:created_at, :name, :slug, :model_no, :product_id)
            .includes(product: :brand)
            .where(id: ids)
        end
      end.sort_by(&:created_at).reverse
    end
  end

  def self.newest_brands
    Rails.cache.fetch('/newest_brands') do
      Brand.order(created_at: :desc).limit(10).to_a
    end
  end
end
