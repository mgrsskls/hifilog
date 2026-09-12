# frozen_string_literal: true

# Authoring source for the "Related Products" block. Design rationale: docs/pairing-graph.md.
#
# Sub categories are named by their stable `identifier`, never by `slug`: a slug follows the sub
# category's name and FriendlyId regenerates it on rename, so referencing one would let a display
# rename silently empty every edge pointing here. SubCategory refuses to change an identifier for
# the same reason.
#
# A ROLE groups sub categories occupying the same position in a signal chain. EDGES are
# directed: an edge declared on role A pointing at role B means "B may be shown on A's
# page". The reverse is a separate declaration, deliberately — a power cable belongs on an
# amplifier page, an amplifier does not belong on a power cable page.
#
# DECLARATION ORDER IS PRIORITY. The order edges are listed is the order their target sub
# categories fill the block. Edges contributed by a specialisation (see below) come before
# the role's common edges, since the thing a product needs is more relevant than the thing
# it merely tolerates.
#
# GATES are conditions on custom attributes (docs §5). Five kinds, all optional per edge:
#
#   source:          the SOURCE product must hold one of these option keys
#   source_excludes: the SOURCE product must NOT hold any of these option keys
#   source_present:  the SOURCE product must hold any value at all for this attribute
#   target:          candidates are narrowed to products holding one of these option keys
#   target_excludes: candidates must NOT hold any of these option keys
#   match:           cross match — the source's value for one attribute must intersect the
#                    candidate's value for another
#
# Option values are declared as i18n KEYS and resolved to stored option ids at query time
# (CustomAttribute#options maps id => key), so renaming an option cannot break a gate and a
# key the definition does not offer fails an invariant test rather than failing silently.
#
# A gate whose attribute is unset on the source fails CLOSED: the edge does not render.
#
# SPECIALISE splits a role by an attribute whose value changes which edges exist rather than
# merely whether one applies (docs §5.1 shape D). When the attribute is unset the role falls
# back to its common `edges:` only — never to a guessed specialisation.
#
# enabled: false marks an edge whose gate cannot be expressed because the attribute does not
# exist yet (docs §5.3). Those edges never render; the comment names what is missing.
#
# same_brand: true marks an edge where components are designed as a system, so a same-brand
# candidate earns a ranking bonus. Capped at one same-brand item per sub category.
# rubocop:disable Metrics/ModuleLength
module RelatedProducts::Graph
  # Destination-only roles: they receive edges and declare none. Listing them as targets
  # everywhere is deliberate repetition — each role reads as a complete chain.
  ROLES = {
    # ---------------------------------------------------------------- vinyl front end
    turntable: {
      sub_categories: %w[turntables],
      edges: [
        { to: :cartridge, same_brand: true },
        { to: :tonearm, same_brand: true },
        { to: :phono_stage, same_brand: true },
        { to: :step_up },
        { to: :cable_phono },
        { to: :support_isolation },
        { to: :support_rack },
        { to: :cable_power }
      ]
    },
    tonearm: {
      sub_categories: %w[tonearms],
      edges: [
        { to: :cartridge, same_brand: true },
        { to: :turntable, same_brand: true },
        { to: :phono_stage, same_brand: true },
        { to: :cable_phono }
      ]
    },
    cartridge: {
      sub_categories: %w[cartridges],
      consumable: true,
      edges: [
        # Cross match: this cartridge's type must be one the stage supports. `optical` is a
        # hard stop, not a preference — an optical cartridge needs its own energiser.
        { to: :phono_stage, same_brand: true,
          match: { source: 'cartridge_type', target: 'supported_cartridge_types' } },
        { to: :tonearm, same_brand: true },
        { to: :turntable, same_brand: true },
        # A step-up transformer is only ever for a moving coil.
        { to: :step_up, source: { 'cartridge_type' => [:mc] } }
      ]
    },
    step_up: {
      sub_categories: %w[mc-step-up-transformers],
      edges: [
        { to: :cartridge, target: { 'cartridge_type' => [:mc] } },
        # Negative gate: a SUT is only useful in front of a stage that cannot do MC itself.
        { to: :phono_stage, target_excludes: { 'supported_cartridge_types' => [:mc] } },
        { to: :turntable },
        { to: :cable_phono }
      ]
    },
    phono_stage: {
      sub_categories: %w[phono-pre-amplifiers],
      edges: [
        { to: :cartridge, same_brand: true,
          match: { source: 'supported_cartridge_types', target: 'cartridge_type' } },
        { to: :turntable, same_brand: true },
        { to: :tonearm, same_brand: true },
        { to: :step_up, source_excludes: { 'supported_cartridge_types' => [:mc] } },
        { to: :preamp, same_brand: true },
        { to: :integrated, same_brand: true },
        { to: :tube_preamp, source: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :tube_rectifier, source: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :cable_interconnect, enabled: false,
          match: { source: %w[input_connectors output_connectors],
                   target: 'cable_interconnect_type' } },
        { to: :cable_phono },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },

    # ------------------------------------------------------------- digital front end
    streamer: {
      sub_categories: %w[streamers],
      edges: [
        { to: :dac, same_brand: true },
        { to: :preamp, same_brand: true },
        { to: :integrated, same_brand: true },
        # Active loudspeakers take their feed straight from a source.
        { to: :speaker_floor, target: { 'loudspeaker_amplification_type' => [:active] } },
        { to: :speaker_standmount, target: { 'loudspeaker_amplification_type' => [:active] } },
        # No attribute describes a digital cable's type — docs §5.3.
        { to: :cable_digital, enabled: false },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },
    cd_transport: {
      sub_categories: %w[cd-transports],
      edges: [
        { to: :dac, same_brand: true },
        { to: :cable_digital, enabled: false },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },
    cd_player: {
      sub_categories: %w[cd-sacd-players],
      edges: [
        { to: :preamp, same_brand: true },
        { to: :integrated, same_brand: true },
        { to: :headphone_amp },
        { to: :headphone_wired, source_present: 'headphone_outputs' },
        { to: :cable_interconnect, enabled: false,
          match: { source: %w[input_connectors output_connectors],
                   target: 'cable_interconnect_type' } },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },
    dac: {
      sub_categories: %w[dacs],
      edges: [
        { to: :streamer, same_brand: true },
        { to: :cd_transport, same_brand: true },
        { to: :preamp, same_brand: true },
        { to: :integrated, same_brand: true },
        { to: :headphone_amp, same_brand: true },
        # Nothing records whether a DAC has volume control, so one that can drive a power
        # amplifier or an active loudspeaker directly cannot be told from one that must feed a
        # pre-amplifier first. docs/pairing-graph.md §5.3.
        { to: :power_amp, enabled: false },
        { to: :headphone_wired, source_present: 'headphone_outputs' },
        { to: :speaker_floor, enabled: false,
          target: { 'loudspeaker_amplification_type' => [:active] } },
        { to: :speaker_standmount, enabled: false,
          target: { 'loudspeaker_amplification_type' => [:active] } },
        { to: :dap },
        { to: :cable_digital, enabled: false },
        { to: :cable_interconnect, enabled: false,
          match: { source: %w[input_connectors output_connectors],
                   target: 'cable_interconnect_type' } },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },
    dap: {
      sub_categories: %w[daps],
      edges: [
        { to: :headphone_wired },
        { to: :headphone_wireless },
        { to: :headphone_amp },
        { to: :dac },
        { to: :cable_headphone, enabled: false }
      ]
    },
    # ----------------------------------------------------------- analog line sources
    #
    # Tape decks and tuners were one role, split because they sit in different categories
    # (Analog / Amplifiers), so the group heading had no single index to link to. Their edge
    # lists are identical; the interconnect match still behaves differently, because
    # `input_connectors` is not attached to tuners and an inapplicable attribute drops out of
    # the union rather than failing the gate.
    tape_deck: {
      sub_categories: %w[tape-decks],
      edges: [
        { to: :preamp, same_brand: true },
        { to: :integrated, same_brand: true },
        { to: :cable_interconnect, enabled: false,
          match: { source: %w[input_connectors output_connectors],
                   target: 'cable_interconnect_type' } },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },
    tuner: {
      sub_categories: %w[tuners],
      edges: [
        { to: :preamp, same_brand: true },
        { to: :integrated, same_brand: true },
        { to: :cable_interconnect, enabled: false,
          match: { source: %w[input_connectors output_connectors],
                   target: 'cable_interconnect_type' } },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },

    # ------------------------------------------------------------------ amplification
    preamp: {
      sub_categories: %w[pre-amplifiers],
      edges: [
        { to: :power_amp, same_brand: true },
        { to: :dac, same_brand: true },
        { to: :phono_stage, same_brand: true },
        { to: :streamer, same_brand: true },
        { to: :cd_player, same_brand: true },
        { to: :tape_deck },
        { to: :tuner },
        { to: :speaker_floor, target: { 'loudspeaker_amplification_type' => [:active] } },
        { to: :speaker_standmount, target: { 'loudspeaker_amplification_type' => [:active] } },
        { to: :headphone_wired, source_present: 'headphone_outputs' },
        { to: :tube_preamp, source: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :tube_rectifier, source: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :cable_interconnect, enabled: false,
          match: { source: %w[input_connectors output_connectors],
                   target: 'cable_interconnect_type' } },
        { to: :switch_box },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },
    power_amp: {
      sub_categories: %w[power-amplifiers],
      edges: [
        # Only passive loudspeakers need a power amplifier.
        #
        # Deliberately NOT gated on `speaker_outputs` being present. Practically every power
        # amplifier, integrated amplifier and receiver has speaker terminals, so that predicate is
        # true of almost every member of these sub categories: it can never exclude a wrong
        # suggestion, only suppress right ones. It was filled on 0 of 267 amplifier products,
        # which hid loudspeakers from every amplifier page in the catalogue. Contrast
        # `headphone_outputs`, which genuinely discriminates and is still gated.
        { to: :speaker_floor, same_brand: true,
          target: { 'loudspeaker_amplification_type' => [:passive] } },
        { to: :speaker_standmount, same_brand: true,
          target: { 'loudspeaker_amplification_type' => [:passive] } },
        { to: :speaker_install,
          target: { 'loudspeaker_amplification_type' => [:passive] } },
        { to: :preamp, same_brand: true },
        # Only a DAC with its own volume control can drive a power amplifier directly.
        { to: :dac, enabled: false },
        { to: :subwoofer, target: { 'loudspeaker_amplification_type' => [:passive] } },
        { to: :tube_power, source: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :tube_rectifier, source: { 'amplifier_type' => [:tube, :hybrid] } },
        # No attribute describes a speaker cable's termination — docs §5.3.
        { to: :cable_speaker, enabled: false },
        { to: :cable_interconnect, enabled: false,
          match: { source: %w[input_connectors output_connectors],
                   target: 'cable_interconnect_type' } },
        { to: :switch_box },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },
    integrated: {
      sub_categories: %w[integrated-amplifiers receivers],
      edges: [
        { to: :speaker_floor, same_brand: true,
          target: { 'loudspeaker_amplification_type' => [:passive] } },
        { to: :speaker_standmount, same_brand: true,
          target: { 'loudspeaker_amplification_type' => [:passive] } },
        { to: :speaker_install,
          target: { 'loudspeaker_amplification_type' => [:passive] } },
        { to: :dac, same_brand: true },
        { to: :streamer, same_brand: true },
        { to: :cd_player, same_brand: true },
        { to: :phono_stage, same_brand: true },
        { to: :subwoofer, target: { 'loudspeaker_amplification_type' => [:passive] } },
        { to: :tape_deck },
        { to: :tuner },
        { to: :headphone_wired, source_present: 'headphone_outputs' },
        { to: :tube_power, source: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :tube_preamp, source: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :tube_rectifier, source: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :cable_speaker, enabled: false },
        { to: :cable_interconnect, enabled: false,
          match: { source: %w[input_connectors output_connectors],
                   target: 'cable_interconnect_type' } },
        { to: :switch_box },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },
    headphone_amp: {
      sub_categories: %w[headphone-amplifiers],
      edges: [
        { to: :headphone_wired, same_brand: true },
        { to: :dac, same_brand: true },
        { to: :dap },
        { to: :cd_player },
        { to: :tube_preamp, source: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :tube_rectifier, source: { 'amplifier_type' => [:tube, :hybrid] } },
        # No attribute describes a headphone's own connector — docs §5.3.
        { to: :cable_headphone, enabled: false },
        { to: :cable_interconnect, enabled: false,
          match: { source: %w[input_connectors output_connectors],
                   target: 'cable_interconnect_type' } },
        { to: :cable_power },
        { to: :power_conditioning },
        { to: :support_rack },
        { to: :support_isolation }
      ]
    },

    # -------------------------------------------------------------------- transducers
    headphone: {
      sub_categories: %w[over-ear-headphones on-ear-headphones in-ear-monitors
                         noise-cancelling-headphones],
      edges: [
        { to: :dap }
      ],
      specialise: {
        attribute: 'headphone_connection_type',
        variants: {
          wired: [
            { to: :headphone_amp, same_brand: true },
            { to: :dac, target_present: 'headphone_outputs' },
            { to: :integrated, target_present: 'headphone_outputs' },
            { to: :cable_headphone, enabled: false }
          ],
          wireless: []
        }
      }
    },
    speaker_floor: {
      sub_categories: %w[floorstanding-loudspeakers],
      edges: [
        { to: :subwoofer, same_brand: true },
        { to: :support_isolation }
      ],
      specialise: {
        attribute: 'loudspeaker_amplification_type',
        variants: {
          passive: [
            { to: :power_amp, same_brand: true },
            { to: :integrated, same_brand: true },
            { to: :cable_speaker, enabled: false }
          ],
          active: [
            { to: :preamp },
            # An active loudspeaker needs a source with volume control; nothing records it.
            { to: :dac, enabled: false },
            { to: :streamer, enabled: false },
            { to: :cable_interconnect, enabled: false,
              match: { source: %w[input_connectors output_connectors],
                       target: 'cable_interconnect_type' } },
            { to: :cable_power },
            { to: :power_conditioning }
          ]
        }
      }
    },
    speaker_standmount: {
      sub_categories: %w[bookshelf-standmount-loudspeakers],
      edges: [
        { to: :subwoofer, same_brand: true },
        { to: :support_speaker },
        { to: :support_isolation }
      ],
      specialise: {
        attribute: 'loudspeaker_amplification_type',
        variants: {
          passive: [
            { to: :power_amp, same_brand: true },
            { to: :integrated, same_brand: true },
            { to: :cable_speaker, enabled: false }
          ],
          active: [
            { to: :preamp },
            # An active loudspeaker needs a source with volume control; nothing records it.
            { to: :dac, enabled: false },
            { to: :streamer, enabled: false },
            { to: :cable_interconnect, enabled: false,
              match: { source: %w[input_connectors output_connectors],
                       target: 'cable_interconnect_type' } },
            { to: :cable_power },
            { to: :power_conditioning }
          ]
        }
      }
    },
    speaker_install: {
      sub_categories: %w[center-channel-speakers in-wall-loudspeakers
                         in-ceiling-loudspeakers on-wall-loudspeakers],
      edges: [
        { to: :subwoofer, same_brand: true }
      ],
      specialise: {
        attribute: 'loudspeaker_amplification_type',
        variants: {
          passive: [
            { to: :power_amp },
            { to: :integrated },
            { to: :cable_speaker, enabled: false }
          ],
          active: [
            { to: :preamp },
            { to: :cable_interconnect, enabled: false,
              match: { source: %w[input_connectors output_connectors],
                       target: 'cable_interconnect_type' } },
            { to: :cable_power },
            { to: :power_conditioning }
          ]
        }
      }
    },
    subwoofer: {
      sub_categories: %w[subwoofers],
      edges: [
        { to: :speaker_floor, same_brand: true },
        { to: :speaker_standmount, same_brand: true },
        { to: :speaker_install }
      ],
      specialise: {
        attribute: 'loudspeaker_amplification_type',
        variants: {
          passive: [
            { to: :power_amp },
            { to: :integrated },
            { to: :cable_speaker, enabled: false }
          ],
          active: [
            { to: :integrated },
            { to: :preamp },
            { to: :cable_interconnect, enabled: false,
              match: { source: %w[input_connectors output_connectors],
                       target: 'cable_interconnect_type' } },
            { to: :cable_power },
            { to: :power_conditioning }
          ]
        }
      }
    },

    # -------------------------------------------------------------------------- tubes
    tube_power: {
      sub_categories: %w[power-tubes],
      consumable: true,
      edges: [
        { to: :power_amp, target: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :integrated, target: { 'amplifier_type' => [:tube, :hybrid] } }
      ]
    },
    tube_preamp: {
      sub_categories: %w[pre-amp-driver-tubes],
      consumable: true,
      edges: [
        { to: :preamp, target: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :integrated, target: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :headphone_amp, target: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :phono_stage, target: { 'amplifier_type' => [:tube, :hybrid] } }
      ]
    },
    tube_rectifier: {
      sub_categories: %w[rectifier-tubes],
      consumable: true,
      edges: [
        { to: :preamp, target: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :power_amp, target: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :integrated, target: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :headphone_amp, target: { 'amplifier_type' => [:tube, :hybrid] } },
        { to: :phono_stage, target: { 'amplifier_type' => [:tube, :hybrid] } }
      ]
    },

    # -------------------------------------------------------------------------- switching
    #
    # NOT network switches. The Switches sub category sits under Accessories: A/B boxes that
    # select between two amplifiers, or between two pairs of loudspeakers. Nothing distinguishes
    # a speaker-level box from a line-level one -- neither input_connectors nor
    # output_connectors is attached to that sub category -- so both readings share one edge
    # list, and the interconnect match passes ungated there by the inapplicability rule.
    switch_box: {
      sub_categories: %w[switches],
      edges: [
        { to: :power_amp },
        { to: :integrated },
        { to: :preamp },
        { to: :speaker_floor, target: { 'loudspeaker_amplification_type' => [:passive] } },
        { to: :speaker_standmount, target: { 'loudspeaker_amplification_type' => [:passive] } },
        { to: :cable_speaker, enabled: false },
        { to: :cable_interconnect, enabled: false,
          match: { source: %w[input_connectors output_connectors],
                   target: 'cable_interconnect_type' } },
        { to: :cable_power },
        { to: :power_conditioning }
      ]
    },

    # ------------------------------------------------- destinations (no outgoing edges)
    cable_speaker: { sub_categories: %w[loudspeaker-cables], edges: [] },
    # Every edge pointing here is currently disabled. The connector match is expressible --
    # cable_interconnect_type against input_connectors / output_connectors -- but those two
    # attributes sit at 0-1% coverage, so the gate closed on every role they apply to while
    # `switches`, which they are not attached to, rendered interconnects ungated. Interconnects
    # appearing only on switch boxes is worse than not appearing at all. docs/pairing-graph.md §5.3.
    cable_interconnect: { sub_categories: %w[interconnects], edges: [] },
    cable_phono: { sub_categories: %w[phono-cables], edges: [] },
    cable_headphone: { sub_categories: %w[headphone-cables], consumable: true, edges: [] },
    cable_digital: { sub_categories: %w[digital-cables], edges: [] },
    cable_power: { sub_categories: %w[power-cables], edges: [] },
    power_conditioning: {
      sub_categories: %w[power-conditioners power-supplies step-up-down-transformers],
      edges: [{ to: :cable_power }]
    },
    support_rack: { sub_categories: %w[racks bases], edges: [] },
    support_speaker: { sub_categories: %w[loudspeaker-stands], edges: [] },
    support_isolation: { sub_categories: %w[pucks-spikes-absorbers], edges: [] }
  }.freeze

  # Specialised role keys (:headphone_wired, :speaker_floor_passive, …) are referenced as edge
  # targets but are not declared roles — they resolve to their base role's sub categories plus
  # a target gate on the specialising attribute.
  SPECIALISED_TARGETS = ROLES.each_with_object({}) do |(role, definition), memo|
    specialise = definition[:specialise]
    next unless specialise

    specialise[:variants].each_key do |value|
      memo[:"#{role}_#{value}"] = { role:, attribute: specialise[:attribute], value: }
    end
  end.freeze

  SUB_CATEGORY_ROLES = ROLES.each_with_object({}) do |(role, definition), memo|
    definition[:sub_categories].each { |identifier| memo[identifier] = role }
  end.freeze

  CONDITION_KEYS = [:source, :target, :source_excludes, :target_excludes].freeze

  class << self
    def role_for(sub_category_identifier)
      SUB_CATEGORY_ROLES[sub_category_identifier]
    end

    def definition(role)
      ROLES[role]
    end

    # The declared role behind a target, which is the target itself unless it is specialised.
    # Groups are per role, so this is what identifies a group.
    # Roles whose candidates are consumables or replacement parts, where being discontinued is
    # normal and often desirable -- NOS valves are the good end of that market. Declared on the
    # role rather than listed elsewhere, so a new valve or stylus role cannot forget to say so.
    # docs/pairing-graph.md §6.3 rule 5.
    def consumable?(role)
      ROLES.dig(base_role(role), :consumable) == true
    end

    def base_role(target)
      SPECIALISED_TARGETS.dig(target, :role) || target
    end

    def specialised?(target)
      SPECIALISED_TARGETS.key?(target)
    end

    # Sub category identifiers a target resolves to, plain or specialised role alike.
    def sub_categories_for(target)
      specialised = SPECIALISED_TARGETS[target]
      return ROLES.fetch(specialised[:role])[:sub_categories] if specialised

      ROLES.fetch(target)[:sub_categories]
    end

    # The implicit target gate a specialised role carries, e.g. :headphone_wired =>
    # { 'headphone_connection_type' => [:wired] }.
    def implicit_target_gate(target)
      specialised = SPECIALISED_TARGETS[target]
      return nil unless specialised

      { specialised[:attribute] => [specialised[:value]] }
    end

    def all_targets
      ROLES.values.flat_map { |definition| declared_edges(definition).map { |edge| edge[:to] } }.uniq
    end

    # Introspection for rake related_products:check, which verifies the graph against a real
    # catalogue -- the fixture database is too small for those invariants to mean anything.
    def every_edge
      ROLES.values.flat_map { |definition| declared_edges(definition) }
    end

    # Every custom attribute label any gate reads, the specialising ones included.
    def gate_attributes
      from_edges = every_edge.flat_map do |edge|
        labels = CONDITION_KEYS.filter_map { |key| edge[key]&.keys }.flatten
        labels << edge[:source_present] if edge[:source_present]
        labels << edge[:target_present] if edge[:target_present]
        if edge[:match]
          labels.concat(Array(edge[:match][:source]))
          labels << edge[:match][:target]
        end
        labels
      end

      (from_edges + ROLES.values.filter_map { |d| d.dig(:specialise, :attribute) }).uniq
    end

    # { attribute label => declared option keys }, for checking the definitions still offer them.
    def gate_option_keys
      every_edge.each_with_object({}) do |edge, memo|
        CONDITION_KEYS.each do |key|
          next unless edge[key]

          edge[key].each { |label, keys| (memo[label] ||= []).concat(keys.map(&:to_s)) }
        end
      end.transform_values(&:uniq)
    end

    # Every option key the graph depends on -- gate conditions and specialisation values alike --
    # as { attribute label => [keys] }. CustomAttribute reads this to refuse removing one, since a
    # key the definition no longer offers turns its gate into something that can never match.
    def referenced_option_keys
      keys = gate_option_keys.transform_values(&:dup)

      ROLES.each_value do |definition|
        specialise = definition[:specialise]
        next unless specialise

        (keys[specialise[:attribute]] ||= []).concat(specialise[:variants].keys.map(&:to_s))
      end

      keys.transform_values(&:uniq)
    end

    def declared_edges(definition)
      specialise = definition[:specialise]
      specialised = specialise ? specialise.fetch(:variants).values.flatten : []
      specialised + definition.fetch(:edges)
    end
  end
end
# rubocop:enable Metrics/ModuleLength
