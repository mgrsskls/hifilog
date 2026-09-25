# frozen_string_literal: true

# One-off backfill for AddProductSeriesIdsToVersions. Run once after that migration deploys; every
# product version from then on sets the column itself (see Product#product_series_ids_for_version).
#
#   bin/rails versions:backfill_product_series_ids
namespace :versions do
  desc 'Backfill versions.product_series_ids for existing product versions'
  task backfill_product_series_ids: :environment do
    # The LIKE only narrows the rows; the YAML tells if the series was set. object_changes of a
    # create or update, object of a destroy (the state before the delete).
    # Any item_type: the versions of a product converted into a variant have the type ProductVariant.
    # A variant has no product_series_id, so its own versions do not match.
    candidates = PaperTrail::Version.where(product_series_ids: nil).where(<<~SQL.squish)
      versions.object_changes LIKE '%product_series_id%'
      OR (versions.event = 'destroy' AND versions.object LIKE '%product_series_id%')
    SQL
    total = candidates.count
    done = 0
    updated = 0

    candidates.find_each do |version|
      ids = if version.event == 'destroy'
              [PaperTrail::Serializers::YAML.load(version.object)['product_series_id']]
            else
              PaperTrail::Serializers::YAML.load(version.object_changes)['product_series_id']
            end
      ids = Array(ids).compact.presence

      if ids
        version.update_columns(product_series_ids: ids) # rubocop:disable Rails/SkipsModelValidations
        updated += 1
      end
      done += 1
      print "\r#{done}/#{total}" if (done % 500).zero?
    end

    puts "\nDone: #{updated} of #{done} candidate versions updated."
  end
end

namespace :versions do
  # One-off cleanup. PaperTrail recorded every touch as an update version without changes: a save
  # of a product touched its brand and its series, a save of a variant touched its product. The
  # models no longer record touches (see docs/catalog-model.md, "Changelog"). A real update always
  # has object_changes (the column exists since the versions table was created), so a version
  # without object_changes, association_changes and comment is a touch. The comment can be an empty
  # string: the series form sends an empty comment, and the touch then records it.
  #
  #   bin/rails versions:delete_touch_versions
  desc 'Delete the update versions without changes that touches created'
  task delete_touch_versions: :environment do
    touches = PaperTrail::Version.where(item_type: %w[Brand Product ProductVariant ProductSeries], event: 'update',
                                        object_changes: nil, association_changes: nil, comment: [nil, ''])
    deleted = 0

    touches.in_batches(of: 1000) do |batch|
      deleted += batch.delete_all
      print "\r#{deleted}"
    end

    puts "\nDone: #{deleted} versions deleted."
  end
end
