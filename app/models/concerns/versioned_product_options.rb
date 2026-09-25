# frozen_string_literal: true

# Writes the product options of a product or a variant into its versions, in
# versions.association_changes. PaperTrail records only the columns of a model, and the options
# are records of their own. The model sets up the callbacks as AssociationVersioning describes.
# See docs/catalog-model.md, "Changelog".
module VersionedProductOptions
  extend ActiveSupport::Concern
  include AssociationVersioning

  # Keeps the options as they are in the database. Call it before the options change: the forms
  # and ActiveAdmin write the options directly, not through a save of the product or variant.
  def remember_product_options
    @product_options_before = product_option_values if @product_options_before.nil?
  end

  # Records a version for a change of the options without a save of the product or variant
  # (ActiveAdmin). No version when the options did not change.
  def record_product_options_version
    paper_trail.record_update(force: true, in_after_callback: false, is_touch: false) if product_options_change
  ensure
    clear_association_changes
  end

  private

  def versioned_association_changes
    change = product_options_change
    change ? super.merge('product_options' => change) : super
  end

  # A new record had no options. For a saved record, the change is known only when
  # #remember_product_options was called before the change.
  def product_options_change
    before = previously_new_record? ? [] : @product_options_before
    return if before.nil?

    after = product_option_values
    [before, after] unless before == after
  end

  # "Option (model no.)", sorted. The values, not the ids: an option has no page, and a deleted
  # option must stay readable in the changelog.
  def product_option_values
    return [] unless persisted?

    foreign_key = self.class.reflect_on_association(:product_options).foreign_key
    ProductOption.where(foreign_key => id).map(&:display_name).sort
  end

  def clear_association_changes
    super
    @product_options_before = nil
  end
end
