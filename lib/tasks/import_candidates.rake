# frozen_string_literal: true

# The three steps between the importer's output and the catalogue.
#
#   import:load[file]  read candidates.jsonl into the staging table
#   import:map         give the candidates a sub category from the mappings
#   import:promote     write the approved candidates as products
#
# They are separate because they fail differently. Loading is a bulk write that
# must be safe to repeat; mapping is a decision applied in bulk; promoting
# writes to the catalogue and must be able to stop on the first row it cannot
# write, without leaving half a product behind.
#
# All three are idempotent. Running them twice changes nothing the second time.
namespace :import do
  desc 'Load tools/brand_importer/var/candidates.jsonl into the staging table'
  task :load, [:file] => :environment do |_task, args|
    require 'json'

    path = args[:file] || Rails.root.join('tools/brand_importer/var/candidates.jsonl')
    abort "no such file: #{path}" unless File.exist?(path)
    # An empty file means the extract that writes it is still running: it is
    # truncated when the run starts and filled as the run goes. Loading it would
    # write an empty batch and report success, which is worse than stopping.
    abort "#{path} is empty. Is `extract` still running? Wait for it to finish." if File.empty?(path)

    batch = ImportBatch.create!(
      source: 'brand_websites',
      started_at: Time.current,
      tool_version: ENV.fetch('IMPORT_TOOL_VERSION', nil)
    )

    brands = Brand.pluck(:slug, :id).to_h
    sub_categories = SubCategory.pluck(:slug, :id).to_h
    # A row that a person has already decided, or corrected by hand, is never
    # overwritten by a later run. Their work is the most valuable thing in the
    # table.
    decided = ImportCandidate.where.not(status: 'pending')
                             .or(ImportCandidate.where.not(edited_at: nil))
                             .pluck(:brand_slug, :source_url).to_set

    rows = []
    seen = 0
    skipped_decided = 0
    unknown_brands = Hash.new(0)
    proposed_count = 0

    write = lambda do
      next if rows.empty?

      # `updated_at` is not in `update_only` and `record_timestamps` is off:
      # the rows carry their own timestamps, and Rails adds its own assignment
      # for `updated_at` on top of whatever is listed here. Both together are
      # two assignments to one column, which Postgres refuses outright.
      ImportCandidate.upsert_all(
        rows,
        unique_by: [:brand_slug, :source_url],
        record_timestamps: false,
        # `description` is neither written nor updated: it is written by people,
        # in the review screen, and never taken from a shop.
        # `sub_category_ids` is not updated: a row that a person or a mapping
        # already classified keeps that answer. The proposal only fills a row
        # the first time it is written.
        update_only: [
          :import_batch_id, :brand_id, :name, :variant_name, :model_no, :price, :price_currency, :release_year, :discontinued, :source_category, :custom_attributes, :image_urls, :variants, :provenance, :score, :warnings, :source_platform, :fingerprint, :match_keys, :validated_at, :validated_by, :validation_note, :validation_verdict
        ]
      )
      rows.clear
    end

    File.foreach(path) do |line|
      data = JSON.parse(line)
      seen += 1
      slug = data['brand_slug'].to_s
      if decided.include?([slug, data['source_url']])
        skipped_decided += 1
        next
      end
      unknown_brands[slug] += 1 unless brands.key?(slug)

      # The classifier's proposal, if the tool wrote one. It is a proposal like
      # every other field here: it fills the staging row, and a person still
      # approves the product. A slug that names no sub category is dropped
      # rather than guessed at.
      proposed = Array(data['sub_category_slugs']).filter_map { |slug| sub_categories[slug] }
      proposed_count += 1 if proposed.any?

      rows << {
        import_batch_id: batch.id,
        brand_id: brands[slug],
        brand_slug: slug,
        name: data['name'],
        variant_name: data['variant_name'],
        model_no: data['model_no'],
        price: data['price'],
        price_currency: data['price_currency'],
        release_year: data['release_year'],
        discontinued: data['discontinued'],
        diy_kit: data['diy_kit'],
        source_category: data['source_category'],
        sub_category_ids: proposed,
        validated_at: data['validated_at'],
        validated_by: data['validated_by'],
        validation_note: data['validation_note'],
        validation_verdict: data['validation_verdict'],
        # The jsonb columns take the Hash or Array itself. The column type
        # encodes it; a String here is stored as one JSON string, and the
        # review screen and the promotion then read text instead of an object.
        custom_attributes: data['custom_attributes'] || {},
        image_urls: data['image_urls'] || [],
        variants: data['variants'] || [],
        provenance: data['provenance'] || {},
        score: data['score'] || 0,
        warnings: data['warnings'] || [],
        source_url: data['source_url'],
        source_platform: data['source_platform'],
        fingerprint: data['fingerprint'],
        match_keys: data['match_keys'] || [],
        status: 'pending',
        created_at: Time.current,
        updated_at: Time.current
      }
      write.call if rows.size >= 1000
    end
    write.call

    # A second reading that found the product out of scope decides the row. It
    # is rejected here, with the reading's note as the reason, so that it does
    # not wait in the review queue for a person to refuse it again. One
    # statement for the whole table; a row that a person edited stays open.
    now = Time.current
    rejected = ImportCandidate.reviewable.untouched
                              .where(validation_verdict: 'out_of_scope')
                              .update_all([
                                            "status = 'rejected', " \
                                            "decision_note = 'read as out of scope: ' || " \
                                            "COALESCE(NULLIF(validation_note, ''), 'not this catalogue'), " \
                                            'reviewed_at = ?, updated_at = ?', now, now
                                          ])

    batch.update!(
      finished_at: Time.current,
      candidates_count: seen - skipped_decided,
      statistics: { read: seen, skipped_decided: skipped_decided,
                    unknown_brands: unknown_brands.size }
    )

    puts "#{seen} row(s) read, #{seen - skipped_decided} written, " \
         "#{skipped_decided} left alone because a person already decided or edited them."
    puts "#{rejected} rejected because a second reading found them out of scope." if rejected.positive?
    puts "#{proposed_count} of them arrived with a sub category from the classifier." if proposed_count.positive?
    if unknown_brands.any?
      puts "\n#{unknown_brands.size} slug(s) match no brand. They are kept and wait:"
      unknown_brands.sort_by { |_slug, count| -count }.first(20).each do |slug, count|
        puts format('  %-40<slug>s %<count>d', slug: slug, count: count)
      end
    end
  end

  desc 'Give unclassified candidates a sub category from the mappings'
  task map: :environment do
    # Every step below writes only rows that no person has edited by hand and
    # that no verdict has decided (`open_to_mapping`). A correction made in the
    # review screen stays, and so does a second reading's answer.
    mapped = 0
    refused = 0
    dated = 0

    ImportCategoryMapping.find_each do |mapping|
      # A whole-brand rule answers every word of that brand, including the
      # products that carry no word at all.
      scope = if mapping.whole_brand?
                ImportCandidate.reviewable.open_to_mapping.where(brand_id: mapping.brand_id)
              else
                base = ImportCandidate.reviewable.open_to_mapping
                                      .unclassified
                                      .where(source_category: mapping.source_category)
                mapping.brand_id ? base.where(brand_id: mapping.brand_id) : base
              end

      if mapping.out_of_scope?
        # A word the shop uses for something this catalogue does not hold. The
        # decision was made once; this applies it.
        refused += scope.update_all(
          status: 'rejected',
          decision_note: "category #{mapping.source_category.inspect} is out of scope",
          reviewed_at: Time.current,
          updated_at: Time.current
        )
      else
        if mapping.sub_category_ids.present?
          # A mapping may name more than one sub category, so the whole set is
          # written. `update_all` needs the array in Postgres' own literal form.
          ids = "{#{mapping.sub_category_ids.join(',')}}"
          mapped += scope.update_all(
            ['sub_category_ids = ?, updated_at = ?', ids, Time.current]
          )
        end

        # "Archived", "Legacy", "Discontinued": the word states the state, and
        # a person decided what it means. That beats an availability flag,
        # which says nothing at all about a product the shop has stopped
        # listing.
        unless mapping.discontinued.nil?
          dated += ImportCandidate.reviewable.untouched
                                  .where(source_category: mapping.source_category)
                                  .then { |rows| mapping.brand_id ? rows.where(brand_id: mapping.brand_id) : rows }
                                  .update_all(discontinued: mapping.discontinued, updated_at: Time.current)
        end
      end
    end

    # A shop writes "Pre-Amplifiers" over its line stages and its phono stages
    # alike, and the product's own name is what separates them. Found by hand:
    # the NAD PP 4, the NAD PP2e and the Emotiva XPS-1 all arrived as line
    # preamplifiers from three different shops.
    #
    # After the mappings rather than inside them, because it corrects what a
    # word cannot know rather than what it means.
    line_stage = SubCategory.find_by(slug: 'pre-amplifiers')
    phono_stage = SubCategory.find_by(slug: 'phono-pre-amplifiers')
    moved = 0
    if line_stage && phono_stage
      moved = ImportCandidate
              .reviewable
              .open_to_mapping
              .where('sub_category_ids @> ARRAY[?]::bigint[]', line_stage.id)
              .where('name ~* ?', '(^|[^a-z])phono([^a-z]|$)')
              .where.not('sub_category_ids @> ARRAY[?]::bigint[]', phono_stage.id)
              .update_all(
                ['sub_category_ids = array_remove(sub_category_ids, ?) || ARRAY[?]::bigint[], ' \
                 'updated_at = ?', line_stage.id, phono_stage.id, Time.current]
              )
    end

    # The same shape for cables. A shop writes "Interconnects" over analogue and
    # digital leads alike, and an AES/EBU, USB, streaming (Ethernet), HDMI or
    # coaxial (BNC) cable carries a digital signal. Found by hand: eleven Chord
    # digital cables over several batches, all arrived as line interconnects.
    interconnect = SubCategory.find_by(slug: 'interconnects')
    digital_cable = SubCategory.find_by(slug: 'digital-cables')
    rerouted = 0
    if interconnect && digital_cable
      rerouted = ImportCandidate
                 .reviewable
                 .open_to_mapping
                 .where('sub_category_ids @> ARRAY[?]::bigint[]', interconnect.id)
                 .where('name ~* ?', 'aes[ ]?/?[ ]?ebu|aes-ebu|aes3|' \
                                     '(^|[^a-z])(usb|ethernet|streaming|lan|hdmi|bnc|coax|coaxial|' \
                                     's/?pdif|toslink|optical|digital|i2s)([^a-z]|$)')
                 .where.not('sub_category_ids @> ARRAY[?]::bigint[]', digital_cable.id)
                 .update_all(
                   ['sub_category_ids = array_remove(sub_category_ids, ?) || ARRAY[?]::bigint[], ' \
                    'updated_at = ?', interconnect.id, digital_cable.id, Time.current]
                 )
    end

    puts "#{mapped} candidate(s) classified, #{refused} refused by a mapping."
    puts "#{moved} moved from line to phono stage, by their own name." if moved.positive?
    puts "#{rerouted} moved from interconnect to digital cable, by their own name." if rerouted.positive?
    puts "#{dated} candidate(s) had their discontinued state set by a mapping." if dated.positive?
    remaining = ImportCandidate.reviewable.unclassified.count
    with_word = ImportCandidate.reviewable.unclassified.where.not(source_category: [nil, '']).count
    puts "#{remaining} still without a sub category; #{with_word} of them state a category " \
         'that has no mapping yet. See Import Candidates -> Unmapped categories in the admin.'
  end

  desc 'Write the approved candidates into the catalogue'
  task promote: :environment do
    # The work is in ImportPromotion, so that it can be tested. This reports.
    results = ImportPromotion.run_all
    written = results.count(&:success?)
    failed = results.reject(&:success?)

    puts "#{written} product(s) written."

    unless failed.empty?
      puts "\n#{failed.size} candidate(s) could not be written and stay approved:"
      failed.first(30).each do |result|
        puts format('  %-50<name>s %<reason>s',
                    name: result.candidate.to_s.truncate(48), reason: result.error)
      end
    end
  end
end
