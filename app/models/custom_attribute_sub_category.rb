# frozen_string_literal: true

# One attribute's applicability to one subcategory, and -- for option types -- which of its
# options apply there.
#
# Additive on purpose. `CustomAttribute has_and_belongs_to_many :sub_categories` and
# `SubCategory has_and_belongs_to_many :custom_attributes` still own the relationship and are
# untouched, so nothing that asks "which attributes apply here" changes. This model exists for
# the row's own columns, `option_ids` and `units`, which HABTM cannot expose.
#
# The consequence of that split is that HABTM writes -- `attribute.sub_categories = [...]` --
# insert and delete rows without this class ever loading, so its callbacks do not fire for
# them. CustomAttribute#clear_cache covers that case, since those writes happen while saving
# the attribute.
class CustomAttributeSubCategory < ApplicationRecord
  self.table_name = 'custom_attributes_sub_categories'

  belongs_to :custom_attribute
  belongs_to :sub_category

  # For direct edits of a subset, which do not go through CustomAttribute and so would not
  # otherwise invalidate the map the form and filter read.
  after_commit { CustomAttribute.clear_sub_category_scope_cache }

  validate :option_ids_must_exist_on_the_attribute
  validate :units_must_be_units_of_the_attribute

  before_validation { self.units = units.compact_blank if units.is_a?(Array) }

  # Why `units` cannot be the units of this sub category, or nil. They are a selection of the
  # units of the attribute. See docs/custom-attributes.md, "Units per sub category".
  def self.units_error(units, attribute_units)
    return if units.blank?

    invalid = units - CustomAttribute::VALID_UNITS
    return "contain invalid values: #{invalid.join(', ')}" if invalid.any?

    foreign = units - attribute_units
    "are not units of the attribute: #{foreign.join(', ')}" if foreign.any?
  end

  private

  # An id that the attribute does not define would silently narrow the subset to nothing
  # visible, which reads as "this category offers no options" rather than as the mistake it is.
  def option_ids_must_exist_on_the_attribute
    return if option_ids.blank?

    known = (custom_attribute&.options || {}).keys
    unknown = option_ids.map(&:to_s) - known

    return if unknown.empty?

    errors.add(:option_ids, "are not options of #{custom_attribute&.label}: #{unknown.join(', ')}")
  end

  # An empty list is allowed here: HABTM writes insert rows without this class, so a link can have
  # no units anyway, and CustomAttribute#units_in falls back to the units of the attribute. The
  # admin form requires units (CustomAttribute#sub_category_units_must_be_chosen).
  def units_must_be_units_of_the_attribute
    error = self.class.units_error(units, custom_attribute&.units || [])
    errors.add(:units, error) if error
  end
end
