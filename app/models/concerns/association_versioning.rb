# frozen_string_literal: true

# Writes changes that are not columns into versions.association_changes, and records an update
# version also when only these changes happened. See docs/catalog-model.md, "Changelog".
#
# The model declares has_paper_trail with on: [] and meta association_changes:
# :association_changes_for_version. After its associations, it adds paper_trail.on_create,
# after_update :record_update_version, paper_trail.on_destroy and after_save
# :clear_association_changes. The associations then save their records before the version is
# written. No paper_trail.on_touch: PaperTrail records every touch as a version without changes,
# and a touch comes from a save of another record. See docs/catalog-model.md, "Changelog".
module AssociationVersioning
  # Records an update version outside of a save, with +changes+ in association_changes, and the
  # changes of the associations. ProductConversionService uses it for the conversion. The column
  # changes of the last save are in the version of that save, so they are cleared first.
  def record_version_with(changes)
    @extra_association_changes = changes
    clear_changes_information
    paper_trail.record_update(force: true, in_after_callback: false, is_touch: false)
  ensure
    @extra_association_changes = nil
    clear_association_changes
  end

  private

  # PaperTrail records an update version only when a column changes. A change of an association
  # is not a column change, so the version is forced then. Otherwise the same as the update
  # callback of PaperTrail.
  def record_update_version
    paper_trail.record_update(force: association_changes_for_version.present?, in_after_callback: true,
                              is_touch: false)
  end

  # { "key" => [old value, new value], ... }, or nil when nothing changed. Same form as
  # object_changes. PaperTrail reads it through the meta option.
  def association_changes_for_version
    versioned_association_changes.presence
  end

  # The including module or model adds its changes with super.
  def versioned_association_changes
    @extra_association_changes || {}
  end

  # After the save, so the next save starts without old changes. The including module or model
  # clears its values with super.
  def clear_association_changes; end
end
