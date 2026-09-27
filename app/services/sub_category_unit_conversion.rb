# frozen_string_literal: true

# Converts the stored figures of products into the units of their sub category, after an admin
# changed the units per sub category. Example: over-ear headphones offered kg and lb, and now
# offer g. A stored "0.35 kg" still shows as "0.35 kg / 0.77 lb" on the product page, and only the
# product form shows "350 g". This service stores "350 g". See docs/custom-attributes.md, "Units
# per sub category".
#
# An entry changes only when its unit is not a unit of the product's sub category. The units come
# from the first sub category in menu order (CustomAttribute#units_for), as in the product form.
# The entry gets the first of these units, converted and rounded like the product form shows it
# (CustomAttribute#entry_in_own_units). A second figure goes, because the new unit has no pair.
# An entry without a unit reads in the first unit of the definition, as on the product page.
#
# Written with update_column, which skips validation and PaperTrail, like the migration
# RestoreStatedImperialFigures: the measurement does not change, so the changelog shows nothing.
# `touch` then sets `updated_at` and clears the caches of the product and its brand. PaperTrail
# records no version for a touch (see AssociationVersioning).
#
# Idempotent: a converted entry is in a unit of its sub category, so a second run changes nothing.
class SubCategoryUnitConversion
  Result = Data.define(:product, :label, :before, :after)

  # `labels`: the attributes to convert, or nil for all number attributes with units.
  def initialize(labels: nil)
    @definitions = CustomAttribute.all_cached.select do |definition|
      definition.number_input_type? && definition.units.any?
    end
    @definitions = @definitions.select { |definition| labels.include?(definition.label) } if labels
    @ranks = CustomAttribute.sub_category_menu_ranks
  end

  # Every entry that would change. Writes only with apply: true.
  def call(apply: false)
    results = []

    products.find_each do |product|
      product_results = @definitions.filter_map { |definition| result_for(product, definition) }
      next if product_results.empty?

      write(product, product_results) if apply
      results.concat(product_results)
    end

    results
  end

  private

  # Only products that store one of the attributes. The GIN index on custom_attributes serves `?|`.
  def products
    labels = @definitions.map(&:label)
    return Product.none if labels.empty?

    Product.where('custom_attributes ?| array[:labels]', labels:).includes(:sub_categories)
  end

  def result_for(product, definition)
    entry = product.custom_attributes&.dig(definition.label)
    return unless entry.is_a?(Hash)

    target = definition.with_units(definition.units_for(product.sub_categories.map(&:id), ranks: @ranks))
    converted = target.entry_in_own_units(entry)
    return if converted == entry || converted.except('unit') == entry.except('unit')

    Result.new(product:, label: definition.label, before: entry, after: converted)
  end

  def write(product, product_results)
    custom_attributes = product.custom_attributes.merge(product_results.to_h { |result| [result.label, result.after] })

    product.update_column(:custom_attributes, custom_attributes) # rubocop:disable Rails/SkipsModelValidations
    product.touch # rubocop:disable Rails/SkipsModelValidations
  end
end
