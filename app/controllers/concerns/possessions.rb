# frozen_string_literal: true

module Possessions
  extend ActiveSupport::Concern

  def possessions_for_user(possessions: [])
    possessions
      .includes([{ product: [{ sub_categories: :category }, :brand] }])
      .includes(
        [
          { product_variant: [
            { product: [
              { sub_categories: :category },
              :brand
            ] }
          ] }
        ]
      )
      .includes(
        [
          { custom_product:
            [
              { sub_categories: :category },
              :user,
              { images_attachments: :blob }
            ] }
        ]
      )
      .includes([{ images_attachments: :blob }])
      .includes([:product_option])
      .includes([:setup_possession])
      .includes([:setup])
      .order(
        [
          'custom_product.name',
          'brand.name',
          'product.name',
          'product_variant.name'
        ]
      )
  end

  # Filters by sub category in SQL so presenters are only built for rows that actually
  # render. Mirrors how the presenters resolve sub categories: PossessionPresenter (via
  # ItemPresenter) delegates to the possession's product, CustomProductPossessionPresenter
  # to the custom product.
  def possessions_in_sub_category(possessions, sub_category)
    possessions.where(<<~SQL.squish, sub_category_id: sub_category.id)
      EXISTS (
        SELECT 1 FROM products_sub_categories psc
        WHERE psc.product_id = possessions.product_id
          AND psc.sub_category_id = :sub_category_id
      )
      OR EXISTS (
        SELECT 1 FROM custom_products_sub_categories cpsc
        WHERE cpsc.custom_product_id = possessions.custom_product_id
          AND cpsc.sub_category_id = :sub_category_id
      )
    SQL
  end

  def grouped_sub_categories(possessions: [])
    format_grouped_sub_categories(
      possessions.flat_map(&:sub_categories).sort_by(&:name).uniq
    )
  end

  # Category nav for a possession scope without hydrating presenters or their images.
  # Two subquery lookups instead of walking every possession in Ruby.
  def grouped_sub_categories_from_scope(possessions:)
    scope = possessions.unscope(:order, :select)

    format_grouped_sub_categories(
      SubCategory.includes(:category)
                 .where(id: sub_category_ids_for_scope(scope))
                 .sort_by(&:name)
    )
  end

  def load_collection_preview(user, limit: 6)
    PossessionPresenterService.map_to_presenters(user.possessions.recent_preview(limit))
  end

  private

  # +reorder(nil)+ drops SubCategory's default_scope ordering: Postgres rejects
  # SELECT DISTINCT when ORDER BY names columns outside the select list.
  def sub_category_ids_for_scope(scope)
    from_products = SubCategory.joins(:products)
                               .where(products: { id: scope.select(:product_id) })
                               .reorder(nil)
                               .distinct
                               .pluck(:id)
    from_custom = SubCategory.joins(:custom_products)
                             .where(custom_products: { id: scope.select(:custom_product_id) })
                             .reorder(nil)
                             .distinct
                             .pluck(:id)

    from_products | from_custom
  end

  def format_grouped_sub_categories(sub_categories)
    sub_categories
      .group_by(&:category)
      .sort_by { |category, _subs| category.order }
      .map do |category, subs|
        [
          category,
          subs.map do |sub_category|
            {
              name: sub_category.name,
              friendly_id: sub_category.friendly_id,
              path: dashboard_products_path(category: sub_category.friendly_id)
            }
          end
        ]
      end
  end
end
