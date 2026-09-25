# frozen_string_literal: true

# Writes the sub categories of a product or a brand into its versions, in
# versions.association_changes. The model sets up the callbacks as AssociationVersioning
# describes, and adds before_add and before_remove: :remember_sub_category_ids to its
# has_and_belongs_to_many :sub_categories. See docs/catalog-model.md, "Changelog".
module VersionedSubCategories
  extend ActiveSupport::Concern
  include AssociationVersioning

  # Changes the sub categories in the block without a version. For the sub categories that a
  # product save adds to its brand (Product#update_brand_sub_categories): the user did not edit
  # the brand.
  def without_sub_category_versioning
    @skip_sub_category_versioning = true
    yield
  ensure
    @skip_sub_category_versioning = false
  end

  private

  # The sub categories before the first change since the last save. A HABTM write on a saved
  # record goes to the database at once, before the save; at the first before_add or
  # before_remove, the association still has the old records.
  def remember_sub_category_ids(_sub_category)
    return if @skip_sub_category_versioning || !@sub_category_ids_before.nil?

    @sub_category_ids_before = sub_category_ids
  end

  def versioned_association_changes
    change = sub_category_ids_change
    change ? super.merge('sub_category_ids' => change) : super
  end

  # [old ids, new ids], sorted, or nil when the sub categories did not change since the last save.
  def sub_category_ids_change
    return if @sub_category_ids_before.nil?

    before = @sub_category_ids_before.sort
    after = sub_category_ids.sort
    [before, after] unless before == after
  end

  def clear_association_changes
    super
    @sub_category_ids_before = nil
  end
end
