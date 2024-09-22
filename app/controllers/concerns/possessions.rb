module Possessions
  extend ActiveSupport::Concern

  def possessions_for_user(user: nil, prev_owned: false, setup: nil)
    all = if setup
            setup.possessions
          else
            user.possessions
          end

    all = map_possessions_to_presenter all.where(prev_owned:)
                                          .includes([product: [{ sub_categories: :category }, :brand]])
                                          .includes(
                                            [
                                              product_variant: [
                                                product: [
                                                  { sub_categories: :category },
                                                  :brand
                                                ]
                                              ]
                                            ]
                                          )
                                          .includes(
                                            [
                                              custom_product:
                                                [
                                                  { sub_categories: :category, },
                                                  :user,
                                                  { image_attachment: :blob }
                                                ]
                                            ]
                                          )
                                          .includes([{ image_attachment: :blob }])
                                          .includes([:product_option])
                                          .includes([:setup_possession])
                                          .includes([:setup])
                                          .order(
                                            [
                                              'brand.name',
                                              'product.name',
                                              'product_variant.name',
                                              'custom_product.name'
                                            ]
                                          )

    @sub_category = SubCategory.friendly.find(params[:category]) if params[:category].present?

    @possessions = if @sub_category
                     all.select { |p| p.sub_categories.include?(@sub_category) }
                   else
                     all
                   end

    @categories = all
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
end
