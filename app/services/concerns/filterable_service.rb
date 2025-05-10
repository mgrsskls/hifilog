module FilterableService
  extend ActiveSupport::Concern
  include FilterConstants

  def apply_letter_filter(scope, value, column)
    scope.where("left(lower(#{column}),1) = ?", value.downcase)
  end

  def extract_filter_context(params)
    return [nil, nil, CustomAttribute.none] if params[:category].blank?

    category_str, sub_category_str = params[:category].split('[')
    sub_category_str = sub_category_str&.chomp(']')

    category = begin
      Category.friendly.find(category_str)
    rescue StandardError
      nil
    end
    sub_category = sub_category_str.present? ? SubCategory.friendly.find(sub_category_str) : nil

    custom_attributes =
      if sub_category
        sub_category.custom_attributes
      elsif category
        CustomAttribute.joins(:sub_categories)
                       .where(sub_categories: { id: category.sub_categories.ids })
                       .distinct
      else
        CustomAttribute.none
      end
    [category, sub_category, custom_attributes]
  end
end
