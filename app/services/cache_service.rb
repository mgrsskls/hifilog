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

  def self.newest_users
    Rails.cache.fetch('/newest_users') do
      User.order(created_at: :desc).limit(5).to_a
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

  def self.newest_events
    Rails.cache.fetch('/newest_events') do
      Event
        .select(:id, :name, :slug, :calendar_year, :created_at)
        .order(created_at: :desc)
        .limit(10)
        .to_a
    end
  end

  # Sub category id lookups for the "Related Products" block: the graph is authored in stable
  # identifiers (see RelatedProducts::Graph) but the query needs ids, and every product page
  # resolves up to eight targets. One pluck for the whole table, cached as plain data.
  #
  # Identifiers, not slugs: a slug follows the sub category's name and FriendlyId regenerates it
  # on rename, which would silently empty every edge pointing at it.
  def self.sub_category_ids_by_identifier
    Rails.cache.fetch('/sub_category_ids_by_identifier') do
      SubCategory.pluck(:identifier, :id).to_h
    end
  end

  def self.sub_category_ids_for(identifiers)
    map = sub_category_ids_by_identifier
    Array(identifiers).filter_map { |identifier| map[identifier] }
  end

  # { sub_category_id => { name:, category_slug:, slug: } }, so a "Related Products" group heading can
  # name and link its sub category without loading the record or its category.
  def self.sub_category_headings
    Rails.cache.fetch('/sub_category_headings') do
      SubCategory
        .joins(:category)
        .pluck(:id, :name, 'categories.slug', :slug)
        .each_with_object({}) do |(id, name, category_slug, slug), memo|
          memo[id] = { name:, category_slug:, slug: }
        end
    end
  end
end
