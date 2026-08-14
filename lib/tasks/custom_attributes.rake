# frozen_string_literal: true

# Bulk creation of CustomAttribute definitions.
#
# Definitions are data, and ActiveAdmin stays the place they are edited. This exists for the
# one thing clicking is bad at: bringing a tranche of them into being, identically, across
# development, staging and production, with a diff someone can review first.
#
# Three things make it worth writing down rather than ticking through the admin form:
#
#   * A label cannot be saved until its `custom_attribute_labels` translation exists, so the
#     locale entry and the definition have to travel together. In a commit they cannot get out
#     of step; by hand, the second half is a thing to remember.
#   * Each definition carries a set of subcategories -- `input_connectors` will span fifteen --
#     and a mis-ticked checkbox fails silently: the field simply never appears for that
#     category. Here a subcategory that does not resolve aborts the run.
#   * "Should this be highlighted?" and "is 4 ohms the right second input?" are review comments
#     on a diff. A clicking session leaves nothing to review.
#
# Idempotent: definitions are matched by label and updated, so a re-run reports no changes.
# Safe to run before or after a deploy, and safe to run twice.
#
#   bin/rails custom_attributes:define

# Ordered i18n keys under `custom_attributes` for option types; ids are never written here.
# See assign_options below for why.
#
# Both start `highlighted: false`, which is a staging decision rather than a judgement about
# the specification. Output power is a key spec by any reading. But `highlighted` is what the
# completeness score counts, and an inapplicable spec is dropped from the denominator rather
# than counted as missing -- so the moment one of these is highlighted, every integrated
# amplifier, power amplifier, receiver, headphone amplifier and digital audio player in the
# catalogue loses points at once and those contribute queues reorder in a single step.
#
# Introducing the field and re-scoring the catalogue are therefore kept as two separate runs:
# flipping this to true later is an ordinary update to the task, and reports as one.
#
# Defined outside the namespace block, not inside it: a constant assigned inside a `namespace
# do...end` still lands on the top-level Object -- the block gives it no scope of its own -- so
# nesting it there would only misdescribe where it lives.
CUSTOM_ATTRIBUTE_DEFINITIONS = [
  {
    label: 'amplifier_output_power',
    input_type: 'number',
    highlighted: false,
    units: %w[w],
    # Power is quoted per load impedance. Two rather than three: 2 ohms is a niche
    # specification, and once this is highlighted every field is one more blank a contributor
    # is scored against.
    inputs: %w[ohm_8 ohm_4],
    sub_categories: %w[integrated-amplifiers power-amplifiers receivers]
  },
  {
    label: 'headphone_amplifier_output_power',
    input_type: 'number',
    highlighted: false,
    units: %w[w],
    # Separate from the above rather than one attribute offering all five impedances:
    # `inputs` is what the product form renders as fields, and a power amplifier has no
    # business being asked for its output into 300 ohms.
    inputs: %w[ohm_32 ohm_300],
    sub_categories: %w[headphone-amplifiers daps]
  },
  # One list per direction, not one per direction and signal type.
  #
  # Splitting analogue from digital would encode in the schema what the option value already
  # says -- `rca` is analogue, `toslink` is digital -- and buy nothing: "has a USB input" is
  # the same single checkbox either way. What it would cost is a boundary to adjudicate for
  # every ambiguous connector (HDMI ARC carries digital audio over a video cable; is Bluetooth
  # a connector?), a contributor being asked to classify what they can see rather than just
  # tick it, and subcategory sets that get it wrong -- a CD transport has no analogue output
  # at all, so an analogue-only attribute had to exclude it, and now it simply appears under
  # `output_connectors` with its digital sockets listed.
  #
  # The in/out split does earn its place: it is not recoverable from the value, since `rca`
  # sits on both sides, and "has a balanced output" is the question people actually ask.
  #
  # Named `input_connectors` rather than `inputs` because `inputs` is already a column on
  # CustomAttribute -- the w/h/l sub-fields -- and `custom_attribute.inputs` beside
  # `custom_attributes['inputs']` would be a permanent misreading waiting to happen.
  #
  # Both reuse the existing `rca` and `xlr` keys rather than minting their own: an RCA socket
  # is an RCA socket wherever it appears, so it should be spelled and renamed in one place.
  # `coaxial` and `optical` are deliberately *not* reused -- they already mean a driver
  # topology and a cartridge type, so these say `spdif_coaxial` and `toslink`.
  {
    label: 'input_connectors',
    input_type: 'options',
    highlighted: false,
    options: %w[rca xlr usb_b usb_c spdif_coaxial toslink aes_ebu i2s bnc hdmi_arc ethernet bluetooth],
    sub_categories: %w[
      integrated-amplifiers pre-amplifiers power-amplifiers receivers
      headphone-amplifiers phono-pre-amplifiers tape-decks dacs streamers
    ],
    # Which of the options apply where. A slug left out offers all of them, which is the right
    # answer for an integrated amplifier or a receiver: those really can have any of these.
    option_scopes: {
      'power-amplifiers' => %w[rca xlr],
      'pre-amplifiers' => %w[rca xlr],
      'tape-decks' => %w[rca xlr],
      'phono-pre-amplifiers' => %w[rca xlr],
      'dacs' => %w[usb_b usb_c spdif_coaxial toslink aes_ebu i2s bnc],
      'streamers' => %w[usb_b spdif_coaxial toslink ethernet bluetooth]
    }
  },
  {
    # Sources and pre-amplifiers only, where "the outputs" needs no qualification.
    #
    # Merging analogue with digital was right -- `rca` is analogue and `toslink` is digital, so
    # the value carries that. Merging *roles* was not: on an integrated amplifier `rca` could be
    # a pre-out, a subwoofer out or a tape loop, and nothing in the word "RCA" says which. Role
    # is genuinely not recoverable from the value, so it needs its own attribute the way
    # direction does -- see headphone_outputs and speaker_outputs below.
    #
    # Which also fixes a lie by omission: with jacks listed here, an integrated amplifier's
    # "Outputs" showed a headphone socket and a pre-out while its actual output, the speaker
    # terminals, was absent entirely.
    label: 'output_connectors',
    input_type: 'options',
    highlighted: false,
    options: %w[rca xlr spdif_coaxial toslink aes_ebu i2s bnc hdmi],
    sub_categories: %w[
      pre-amplifiers phono-pre-amplifiers dacs cd-sacd-players
      cd-transports streamers tuners tape-decks
    ],
    # Every subcategory is scoped, none left to default: an option added to a merged attribute
    # widens every *unscoped* subcategory automatically, which is how the jacks reached CD
    # players and streamers by omission rather than by decision.
    option_scopes: {
      'pre-amplifiers' => %w[rca xlr],
      'phono-pre-amplifiers' => %w[rca xlr],
      'tuners' => %w[rca xlr],
      'tape-decks' => %w[rca xlr],
      'dacs' => %w[rca xlr],
      'cd-sacd-players' => %w[rca xlr spdif_coaxial toslink aes_ebu i2s bnc hdmi],
      'streamers' => %w[rca xlr spdif_coaxial toslink aes_ebu i2s bnc],
      # A transport has no analogue stage at all; its whole job is to hand the bits on.
      'cd-transports' => %w[spdif_coaxial toslink aes_ebu i2s bnc]
    }
  },
  # The role is in the label, the connector is in the value. That split is what lets an
  # integrated amplifier answer all three output questions without any of them being ambiguous.
  {
    label: 'headphone_outputs',
    input_type: 'options',
    highlighted: false,
    options: %w[jack_3_5mm jack_4_4mm jack_6_35mm xlr_4pin],
    sub_categories: %w[
      headphone-amplifiers daps dacs cd-sacd-players integrated-amplifiers receivers
    ],
    option_scopes: {
      'headphone-amplifiers' => %w[jack_3_5mm jack_4_4mm jack_6_35mm xlr_4pin],
      'dacs' => %w[jack_6_35mm jack_4_4mm xlr_4pin],
      'daps' => %w[jack_3_5mm jack_4_4mm],
      'integrated-amplifiers' => %w[jack_6_35mm jack_4_4mm],
      'receivers' => %w[jack_6_35mm],
      'cd-sacd-players' => %w[jack_6_35mm]
    }
  },
  {
    # Left unscoped deliberately: all three terminals are plausible on all three kinds of
    # amplifier, so there is nothing here to narrow.
    label: 'speaker_outputs',
    input_type: 'options',
    highlighted: false,
    options: %w[binding_posts speakon spring_clips],
    sub_categories: %w[power-amplifiers integrated-amplifiers receivers]
  }
].freeze

# The namespace block bundles the task with the private helpers `apply` builds on, which is
# the normal shape of a Rake task -- not a sign that one block is doing too much.
# rubocop:disable Metrics/BlockLength
namespace :custom_attributes do
  desc 'Create or update the declared CustomAttribute definitions (idempotent).'
  task define: :environment do
    # The declarations reach for columns a pending migration may not have added yet, and an
    # unmigrated database fails deep inside with a bare NoMethodError naming a column rather
    # than the migration behind it. This is the same check the server performs on boot.
    ActiveRecord::Migration.check_all_pending!

    results = CUSTOM_ATTRIBUTE_DEFINITIONS.map { |declaration| apply(declaration) }

    report(results)
  end

  def apply(declaration)
    record = CustomAttribute.find_or_initialize_by(label: declaration[:label])
    before = snapshot(record)

    record.assign_attributes(
      input_type: declaration[:input_type],
      highlighted: declaration[:highlighted],
      units: declaration[:units] || [],
      inputs: declaration[:inputs] || []
    )

    assign_options(record, declaration[:options])
    record.sub_categories = resolve_sub_categories(declaration)

    scopes_settled = before[:persisted] && option_scopes_settled?(record, declaration)

    return [declaration[:label], :unchanged, nil] if snapshot(record) == before && scopes_settled

    action = before[:persisted] ? :updated : :created

    return [declaration[:label], :invalid, record.errors.full_messages] unless record.save

    # After the save: the join rows do not exist until the HABTM assignment above is written,
    # and the option ids being narrowed to have to exist on the record first.
    apply_option_scopes(record, declaration)

    [declaration[:label], action, nil]
  end

  # Narrows an attribute's options per subcategory. A slug the declaration does not mention is
  # reset to the empty array, which means "all of them" -- so removing a line here widens the
  # list again rather than leaving a stale narrowing behind.
  def apply_option_scopes(record, declaration)
    desired = desired_option_scopes(record, declaration)

    links_for(record).each do |slug, link|
      ids = desired.fetch(slug, [])

      link.update!(option_ids: ids) unless link.option_ids.sort == ids.sort
    end
  end

  def option_scopes_settled?(record, declaration)
    desired = desired_option_scopes(record, declaration)

    links_for(record).all? { |slug, link| link.option_ids.sort == desired.fetch(slug, []).sort }
  end

  # Declared as option i18n keys, translated here to the ids products store -- the same reason
  # assign_options never writes an id. `fetch` rather than `[]`: a key that is not one of the
  # attribute's own options is a mistake worth stopping for, not an empty narrowing to puzzle
  # over later.
  def desired_option_scopes(record, declaration)
    declared = declaration[:option_scopes] || {}
    return {} if declared.empty?

    ids_by_key = (record.options || {}).invert

    declared.transform_values do |keys|
      keys.map do |key|
        ids_by_key.fetch(key) do
          raise "#{declaration[:label]}: #{key} is scoped to a sub category but is not one of its options"
        end
      end
    end
  end

  def links_for(record)
    CustomAttributeSubCategory.where(custom_attribute_id: record.id)
                              .includes(:sub_category)
                              .index_by { |link| link.sub_category.slug }
  end

  # Options are declared as i18n keys, never as ids, because the id is the part products store.
  # Existing keys are handed back to `options_attributes=` with the id they already hold so a
  # re-run cannot renumber them; a new key arrives with a blank id and is assigned one above the
  # highest ever used.
  #
  # Dropping a key from the declaration would remove the option, which is the one thing the
  # admin form asks for confirmation before doing. Here it raises instead: a rake task is the
  # wrong place to silently orphan the products still pointing at it.
  def assign_options(record, keys)
    return if keys.blank?

    ids_by_key = (record.options || {}).invert
    removed = ids_by_key.keys - keys

    if removed.any?
      counts = record.option_usage_counts
      in_use = removed.select { |key| counts[ids_by_key[key].to_s].to_i.positive? }

      if in_use.any?
        raise "#{record.label}: #{in_use.join(', ')} would be removed but #{in_use.map do |key|
          counts[ids_by_key[key].to_s]
        end.sum} product(s) still use them. Remove them in ActiveAdmin, which reports the counts per option."
      end
    end

    record.options_attributes = keys.map { |key| { 'key' => ids_by_key[key].to_s, 'value' => key } }
  end

  # By slug, not name or id: names get edited and ids differ per environment. An unresolved slug
  # aborts the whole run rather than quietly producing a definition attached to fewer categories
  # than intended -- the exact silent failure this task exists to avoid.
  def resolve_sub_categories(declaration)
    slugs = Array(declaration[:sub_categories])
    found = SubCategory.where(slug: slugs).to_a
    missing = slugs - found.map(&:slug)

    raise "#{declaration[:label]}: no sub category with slug #{missing.join(', ')}" if missing.any?

    found
  end

  # Everything a re-run could change, so "unchanged" means unchanged rather than "saved without
  # raising". Sorted because neither the unit list nor the subcategory order is meaningful.
  def snapshot(record)
    {
      persisted: record.persisted?,
      input_type: record.input_type,
      highlighted: record.highlighted,
      units: record.units.to_a.sort,
      inputs: record.inputs.to_a.sort,
      options: record.options,
      sub_category_ids: record.sub_category_ids.sort
    }
  end

  # CustomAttribute.all_cached is invalidated by an after_commit, which is enough when the write
  # happens in the process doing the reading. A rake task is by definition another process, so
  # with a per-process store -- :memory_store, which development uses whenever
  # tmp/caching-dev.txt exists -- the callback clears this task's copy and leaves the running
  # server's untouched. The product form reads all_cached and would go on rendering the old set,
  # while the category filter, which queries live, already shows the new one.
  #
  # Production's :mem_cache_store is shared between processes, so the callback lands there.
  def warn_about_per_process_cache
    return unless Rails.cache.is_a?(ActiveSupport::Cache::MemoryStore)

    puts "\nNote: this environment caches definitions per process, so a running server still " \
         'holds the previous set. Restart it to see these on the product form.'
  end

  def report(results)
    results.each do |label, outcome, errors|
      puts format('%-14<outcome>s %<label>s%<errors>s', outcome:, label:,
                                                        errors: errors ? " -- #{errors.to_sentence}" : '')
    end

    invalid = results.count { |_, outcome, _| outcome == :invalid }

    if invalid.zero?
      puts "\n#{results.size} definition(s) processed."
      warn_about_per_process_cache if results.any? { |_, outcome, _| [:created, :updated].include?(outcome) }
      return
    end

    # The per-line validation messages above are the reason. This used to name one likely cause
    # -- a missing translation -- which read as a diagnosis and sent the reader to the wrong
    # file when the actual failure was something else entirely.
    abort "\n#{invalid} definition(s) could not be saved; see the errors above."
  end
end
# rubocop:enable Metrics/BlockLength
