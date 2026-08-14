# frozen_string_literal: true

# One attribute's applicability to one subcategory, and -- for option types -- which of its
# options apply there.
#
# Additive on purpose. `CustomAttribute has_and_belongs_to_many :sub_categories` and
# `SubCategory has_and_belongs_to_many :custom_attributes` still own the relationship and are
# untouched, so nothing that asks "which attributes apply here" changes. This model exists for
# the row's own column, `option_ids`, which HABTM cannot expose.
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
end
