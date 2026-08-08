# frozen_string_literal: true

# Applies submitted product-option rows (option + model_no, keyed by id when editing an
# existing row) to a Product or ProductVariant. Both models expose the same +product_options+
# has_many, so the assignment logic is identical either way.
module ProductOptionsAssignable
  extend ActiveSupport::Concern

  private

  def assign_product_options(record, options_attributes)
    product_options = record.product_options

    options_attributes.each_value do |attribute|
      model_no = attribute[:model_no]
      option = attribute[:option]
      id = attribute[:id]

      if id.present?
        product_option = product_options.find(id)

        if option.present? || model_no.present?
          product_option.update(option:, model_no:)
        else
          product_option.delete
        end
      elsif option.present?
        product_options << ProductOption.new(option:, model_no:)
      end
    end
  end
end
