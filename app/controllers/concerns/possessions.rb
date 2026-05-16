# frozen_string_literal: true

module Possessions
  extend ActiveSupport::Concern

  def get_possessions_for_user(possessions: [])
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

  def get_grouped_sub_categories(possessions: [])
    possessions
      .flat_map(&:sub_categories)
      .sort_by(&:name)
      .uniq
      .group_by(&:category)
      .sort_by { |category| category[0].order }
      .map do |c|
        [
          c[0],
          c[1].map do |sub_category|
            {
              name: sub_category.name,
              friendly_id: sub_category.friendly_id,
              path: dashboard_products_path(category: sub_category.friendly_id)
            }
          end
        ]
      end
  end

  def filter_presenters_by_category(all, category_param: params[:category])
    sub_category = SubCategory.friendly.find(category_param) if category_param.present?
    possessions = sub_category ? all.select { |p| p.sub_categories.include?(sub_category) } : all
    categories = get_grouped_sub_categories(possessions: all)
    [possessions, categories, sub_category]
  end

  def load_collection_preview(user, limit: 6)
    PossessionPresenterService.map_to_presenters(user.possessions.recent_preview(limit))
  end
end
