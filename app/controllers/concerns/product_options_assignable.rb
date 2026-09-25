# frozen_string_literal: true

# Applies submitted product-option rows (option + model_no, keyed by id when editing an
# existing row) to a Product or ProductVariant. Both models expose the same +product_options+
# has_many, so the assignment logic is identical either way.
module ProductOptionsAssignable
  extend ActiveSupport::Concern

  private

  # Writes the options and saves a saved record (the block) in one transaction. The option rows of
  # a saved record are written at once, so a failed save must undo them too; otherwise the options
  # change without a version. Returns true when the block saved the record.
  # rubocop:disable Naming/PredicateMethod
  def save_with_product_options(record, options_attributes)
    # rubocop:enable Naming/PredicateMethod
    saved = ActiveRecord::Base.transaction do
      assign_product_options(record, options_attributes) if options_attributes.present?
      yield || raise(ActiveRecord::Rollback)
    end
    saved == true
  end

  # The rows are written at once, before the save of the record. The record keeps the old options
  # for its next version (VersionedProductOptions).
  def assign_product_options(record, options_attributes)
    record.remember_product_options
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
