module FilterableService
  extend ActiveSupport::Concern
  include FilterConstants

  def extract_category(category_param)
    return [nil, nil] if category_param.blank?

    category_str, sub_category_str = category_param.split('[')
    sub_category_str = sub_category_str&.chomp(']')

    category = begin
      Category.friendly.find(category_str)
    rescue StandardError
      nil
    end
    sub_category = sub_category_str.present? ? SubCategory.friendly.find(sub_category_str) : nil

    [category, sub_category]
  end

  def extract_custom_attributes(category, sub_category)
    return CustomAttribute.none if category.blank? && sub_category.blank?

    return sub_category.custom_attributes if sub_category.present?

    if category.present?
      return CustomAttribute.joins(:sub_categories)
                            .where(sub_categories: { id: category.sub_category_ids })
                            .group('custom_attributes.id')
    end

    CustomAttribute.none
  end

  def build_custom_attributes_hash(custom_attributes)
    if custom_attributes.any?
      custom_attributes.map do |custom_attribute|
        if custom_attribute[:inputs].present?
          {
            custom_attribute[:label] => [
              :unit,
              custom_attribute[:inputs].map do |input|
                { input => [:min, :max] }
              end
            ]
          }
        elsif custom_attribute[:input_type] == 'number'
          {
            custom_attribute[:label] => [:min, :max, :unit]
          }
        elsif custom_attribute[:input_type] == 'boolean'
          custom_attribute[:label]
        else
          {
            custom_attribute[:label] => []
          }
        end
      end
    else
      []
    end
  end
end
