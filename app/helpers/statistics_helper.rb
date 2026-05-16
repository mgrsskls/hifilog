# frozen_string_literal: true

module StatisticsHelper
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper

  def current_overview_statistics(products_count:, brands_count:, spendings: nil, user_name: nil)
    arr = [{
      label: user_name.present? ? "#{user_name} currently owns" : 'You currently own',
      value: products_count,
      unit: Product.model_name.human(count: products_count)
    }, {
      label: user_name.present? ? "#{user_name} owns products from" : 'You own products from',
      value: brands_count,
      unit: Brand.model_name.human(count: brands_count)
    }]

    unless spendings.nil?
      arr << {
        label: user_name.present? ? "#{user_name}'s collection cost" : 'Your collection cost',
        value: spendings.any? ? number_with_delimiter(number_to_rounded(spendings[0][:spendings], precision: 0)) : 0,
        unit: spendings.any? && spendings[0][:currency].present? ? spendings[0][:currency] : 'n/a'
      }
    end

    arr
  end
end
