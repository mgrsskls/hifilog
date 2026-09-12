# Pairing graph — draft for review

Authoring source for the **Related Products** block on catalogue detail pages. Roles are an **authoring-time** abstraction;
what ships to the database is a directed subcategory→subcategory pair table generated
from this file, in the same spirit as `rake custom_attributes:define`: a reviewable
declaration that materialises into rows, not a second source of truth at runtime.

Edges marked **†** are conditional on custom attributes — see §5. An unmarked
edge always applies.

Edges are **directed**. `a -> b` means "b may be shown on a's page". Most pairs are
symmetric and are declared once under `both:`, but hubs (power, cables, support) are
one-way on purpose: a power cable belongs on an amplifier page, an amplifier does not
belong on a power cable page.

---

## 1. Role assignments

All 45 subcategories, one role each.

| Role                 | Subcategories (id)                                                           |
| -------------------- | ---------------------------------------------------------------------------- |
| `turntable`          | Turntables (17)                                                              |
| `tonearm`            | Tonearms (18)                                                                |
| `cartridge`          | Cartridges (13)                                                              |
| `step_up`            | MC Step-Up Transformers (35)                                                 |
| `phono_stage`        | Phono Pre-Amplifiers / Stages (2)                                            |
| `analog_source`      | Tape Decks (139), Tuners (73)                                                |
| `cd_player`          | CD/SACD Players (15)                                                         |
| `cd_transport`       | CD Transports (74)                                                           |
| `streamer`           | Streamers (19)                                                               |
| `dac`                | Digital Audio Converters (16)                                                |
| `dap`                | Digital Audio Players (36)                                                   |
| `switch_box`         | Switches (37)                                                                |
| `preamp`             | Pre-Amplifiers (1)                                                           |
| `power_amp`          | Power Amplifiers (4)                                                         |
| `integrated`         | Integrated Amplifiers (3), Receivers (20)                                    |
| `headphone_amp`      | Headphone Amplifiers (5)                                                     |
| `headphone`          | Over-Ear (8), On-Ear (7), In-Ear Monitors (6), Noise Cancelling (9)          |
| `speaker_floor`      | Floorstanding Loudspeakers (11)                                              |
| `speaker_standmount` | Bookshelf & Standmount Loudspeakers (10)                                     |
| `speaker_install`    | Center Channel (21), In-Wall (34), In-Ceiling (33), On-Wall (75)             |
| `subwoofer`          | Subwoofers (12)                                                              |
| `cable_speaker`      | Loudspeaker Cables (24)                                                      |
| `cable_interconnect` | Interconnects (25)                                                           |
| `cable_phono`        | Phono Cables (76)                                                            |
| `cable_headphone`    | Headphone Cables (27)                                                        |
| `cable_digital`      | Digital Cables (28)                                                          |
| `cable_power`        | Power Cables (26)                                                            |
| `power_conditioning` | Power Conditioners (32), Power Supplies (40), Step Up/Down Transformers (39) |
| `tube_power`         | Power Tubes (29)                                                             |
| `tube_preamp`        | Pre-Amp / Driver Tubes (31)                                                  |
| `tube_rectifier`     | Rectifier Tubes (30)                                                         |
| `support_rack`       | Racks (107), Bases (23)                                                      |
| `support_speaker`    | Loudspeaker Stands (106)                                                     |
| `support_isolation`  | Pucks, Spikes, Absorbers (22)                                                |

34 roles for 45 subcategories. The ratio is poor, which is the point of keeping roles
out of the runtime schema: they collapse meaningfully only for headphones (4→1),
speakers (7→4) and a few pairs. The database stores subcategory pairs.

---

## 2. Edges

### Vinyl front end

```
turntable      both: cartridge, tonearm, phono_stage, step_up
               out:  cable_phono, cable_power, support_rack, support_isolation
tonearm        both: cartridge, turntable, phono_stage
               out:  cable_phono
cartridge      both: turntable, tonearm, phono_stage †, step_up †
step_up        both: cartridge †, phono_stage †, turntable
phono_stage    both: turntable, cartridge †, tonearm, step_up †, preamp, integrated
               out:  cable_interconnect †, cable_phono, cable_power,
                     tube_preamp †, tube_rectifier †, support_rack, support_isolation
```

### Digital front end

```
streamer       both: dac, network, preamp, integrated
               out:  cable_digital, cable_power, support_rack
cd_transport   both: dac
               out:  cable_digital, cable_power, support_rack
cd_player      both: preamp, integrated, headphone_amp
               out:  cable_interconnect †, cable_power, support_rack
dac            both: streamer, cd_transport, network, preamp, integrated,
                     power_amp, headphone_amp, headphone †, dap
               out:  cable_digital, cable_interconnect †, cable_power, support_rack
network        both: streamer, dac
               out:  cable_digital, cable_power
dap            both: headphone, headphone_amp, dac
               out:  cable_headphone
```

### Analog line sources

```
analog_source  both: preamp, integrated
               out:  cable_interconnect, cable_power, support_rack
```

### Amplification

```
preamp         both: power_amp, dac, phono_stage, streamer, cd_player, analog_source
               out:  cable_interconnect †, cable_power, tube_preamp †, tube_rectifier †,
                     support_rack, support_isolation
power_amp      both: preamp, dac, speaker_floor †, speaker_standmount †,
                     speaker_install †, subwoofer †
               out:  cable_speaker †, cable_interconnect †, cable_power,
                     tube_power †, tube_rectifier †, support_rack
integrated     both: speaker_floor †, speaker_standmount †, speaker_install †,
                     subwoofer †, dac, streamer, cd_player, phono_stage,
                     analog_source, headphone †
               out:  cable_speaker †, cable_interconnect †, cable_power,
                     tube_power †, tube_preamp †, tube_rectifier †, support_rack
headphone_amp  both: headphone †, dac, dap, cd_player
               out:  cable_headphone †, cable_interconnect †, cable_power,
                     tube_preamp †, tube_rectifier †, support_rack
```

### Transducers

```
headphone          both: headphone_amp †, dac †, dap, integrated †
                   out:  cable_headphone †
speaker_floor      both: power_amp †, integrated †, subwoofer
                   out:  cable_speaker †, support_isolation
speaker_standmount both: power_amp †, integrated †, subwoofer
                   out:  cable_speaker †, support_speaker, support_isolation
speaker_install    both: power_amp †, integrated †, subwoofer
                   out:  cable_speaker †
subwoofer          both: speaker_floor, speaker_standmount, speaker_install,
                         integrated †, power_amp †
                   out:  cable_speaker †, cable_interconnect †, cable_power
```

### Hubs (one-way in, deliberately)

These have no outgoing edges of their own. A power cable page shows other power
cables' neighbours to nobody; it is a destination, not a source of suggestions.

```
cable_power         in: every mains-powered role
                        (turntable, phono_stage, streamer, cd_transport, cd_player,
                         dac, network, preamp, power_amp, integrated, headphone_amp,
                         subwoofer, power_conditioning)
power_conditioning  in: same set as cable_power
                        out: cable_power
support_rack        in: all component roles (not speakers, headphones, cables)
support_isolation   in: all component roles + speaker_floor, speaker_standmount
support_speaker     in: speaker_standmount only
```

### Tubes

```
tube_power      both: power_amp †, integrated †
tube_preamp     both: preamp †, integrated †, headphone_amp †, phono_stage †
tube_rectifier  both: preamp †, power_amp †, integrated †, headphone_amp †, phono_stage †

(`tube_preamp -> dac` was in the first draft and is dropped: `amplifier_type` is
not attached to the DACs subcategory, so a tube-output DAC cannot be identified.
See the gaps table in §5.)
```

---

## 3. The turntable/headphone test

An Over-Ear Headphones page resolves to: Headphone Amplifiers, DACs, Digital Audio
Players, Integrated Amplifiers, Headphone Cables. `turntable` is not reachable — it is
four hops away through `phono_stage → preamp → power_amp`, and no edge shortcuts it.

A Turntables page resolves to: Cartridges, Tonearms, Phono Pre-Amplifiers, MC Step-Up
Transformers, Phono Cables, Power Cables, Racks, Bases, Pucks/Spikes/Absorbers. No
headphones, no speakers, no DACs.

---

## 4. Open questions

**Center channels sit in `speaker_install`.** Convenient rather than correct — they are
a stereo-adjacent AV item, and hifilog is explicitly home hi-fi, not AV. If the
category stays, it may deserve its own role, or none.

**`speaker_standmount -> support_speaker` is the one edge that is really per-subcategory
rather than per-role.** Stands belong on bookshelf pages and not on floorstander pages,
which is precisely why Bookshelf and Floorstanding are separate roles here. If more
edges turn out to be like this, the role layer is not paying for itself and the pairs
should be hand-authored directly.

**Fan-out needs capping at display time, not in the graph.** `integrated` reaches 17
roles. The graph decides what is _permitted_; the page decides what is _shown_ — suggest
a cap of ~4 subcategories per page, ordered by the ranking signal below, 3 products each.

**Ranking is unresolved and unresolvable today.** Ordering within the permitted set
wants co-occurrence, and the current data (8 setups, 22 setup memberships, 135
possessions across 37 users) cannot supply it. Until it can, order by subcategory
priority declared here plus product completeness, so the block is deterministic and
never presents one person's system as a trend.

---

## 5. Attribute gates

Tubes are not a special case, they are the most obvious member of a class. Nine
edge groups are wrong without a condition on the product's custom attributes, and
they do not all want the same mechanism.

### 5.1 Four shapes of gate

**A — source gate.** The edge exists only if the _source_ product holds a value.
One predicate, evaluated once per page.

> Power Tubes appear on an amplifier page only when `amplifier_type ∈ {tube, hybrid}`.

**B — target filter.** The edge always exists; the candidate set inside the target
subcategory is narrowed. A `WHERE` on `products.custom_attributes`, already covered
by `index_products_on_custom_attributes` (GIN).

> An MC Step-Up Transformer page lists only cartridges with `cartridge_type = mc`.

**C — cross match.** The source's value must intersect the target's. The source
value is substituted into the target query at request time, so the declaration
format has to support parameters, not just literals.

> A cartridge is shown on a phono stage only when its `cartridge_type` is in that
> stage's `supported_cartridge_types`.

**D — role specialisation.** The attribute does not merely _remove_ edges, it
_changes_ them. Handle this by splitting the role at resolve time rather than
putting conditions on every edge.

> A passive loudspeaker wants a power amplifier and speaker cable. An active one
> wants a preamp or DAC, an interconnect and a power cable. Two different edge sets,
> not one set minus a filter.

Only two roles need shape D, and both are already `highlighted` attributes:

| Role                     | Attribute                        | Specialises into     | Edges                                                  |
| ------------------------ | -------------------------------- | -------------------- | ------------------------------------------------------ |
| `speaker_*`, `subwoofer` | `loudspeaker_amplification_type` | `…_passive`          | power_amp, integrated, cable_speaker                   |
|                          |                                  | `…_active`           | preamp, dac, streamer, cable_interconnect, cable_power |
| `headphone`              | `headphone_connection_type`      | `headphone_wired`    | headphone_amp, dac, dap, integrated, cable_headphone   |
|                          |                                  | `headphone_wireless` | dap only                                               |

### 5.2 Inventory

| #   | Edges                                                                        | Attribute                                                          | Condition                           | Shape                                          |
| --- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------ | ----------------------------------- | ---------------------------------------------- |
| 1   | `tube_power ↔ power_amp, integrated`                                         | `amplifier_type`                                                   | `∈ {tube, hybrid}`                  | A + B                                          |
| 2   | `tube_preamp ↔ preamp, integrated, headphone_amp, phono_stage`               | `amplifier_type`                                                   | `∈ {tube, hybrid}`                  | A + B                                          |
| 3   | `tube_rectifier ↔ preamp, power_amp, integrated, headphone_amp, phono_stage` | `amplifier_type`                                                   | `∈ {tube, hybrid}`                  | A + B                                          |
| 4   | all `speaker_* / subwoofer` amplification edges                              | `loudspeaker_amplification_type`                                   | passive vs active                   | D                                              |
| 5   | all `headphone` edges                                                        | `headphone_connection_type`                                        | wired vs wireless                   | D                                              |
| 6   | `integrated, preamp, cd_player, dac, dap → headphone`                        | `headphone_outputs`                                                | non-empty                           | A                                              |
| 7   | ~~`power_amp, integrated → speaker_*`~~                                      | `speaker_outputs`                                                  | ~~non-empty~~                       | **removed** — near-universal predicate, see §8 |
| 8   | `cartridge ↔ phono_stage`                                                    | `cartridge_type`, `supported_cartridge_types`                      | source value ∈ target set           | C                                              |
| 9   | `step_up ↔ cartridge`                                                        | `cartridge_type`                                                   | `= mc`                              | B                                              |
| 10  | `step_up ↔ phono_stage`                                                      | `supported_cartridge_types`                                        | **excludes** `mc`                   | B (negative)                                   |
| 11  | every `cable_interconnect` edge                                              | `cable_interconnect_type`, `input_connectors`, `output_connectors` | cable type ∈ component's connectors | C — **disabled**, see §5.3                     |

`amplifier_type` is attached to all six amplifier subcategories including
Phono Pre-Amplifiers, so gates 1–3 resolve cleanly. `loudspeaker_amplification_type`
covers all seven loudspeaker subcategories including Subwoofers.

Two of these are corrections to the first draft rather than additions:

- **#10.** A step-up transformer is only useful in front of a phono stage that
  _cannot_ do MC itself. The first draft paired them unconditionally, which is
  backwards — it recommends a SUT precisely to the people who least need one.
- **#8, `optical`.** `cartridge_type` and `supported_cartridge_types` both carry
  `optical`. An optical cartridge needs a matching energiser and is not usable with
  any MM/MC stage, so this is not a preference but a compatibility hard stop.

**#11 is the widest-reaching of the lot.** Interconnects touch nearly every
component, and `output_connectors` / `input_connectors` are attached to eleven and
nine subcategories respectively. Suggesting XLR interconnects for an RCA-only
integrated is exactly the same class of error as KT88s on a Class D amplifier, and
it will happen far more often.

### 5.3 Gaps — cases that want a gate and have no attribute to gate on

| Edge                                                      | What is missing                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cable_headphone ↔ headphone`                             | No headphone-side connector attribute. `headphone_connection_type` is only wired/wireless, and `headphone_outputs` describes the _amplifier_. Wants e.g. `headphone_cable_connector` on both sides — and the option vocabulary has no `mmcx` or `2_pin` yet, which are the two most common.                                                                                                                                                                                              |
| `cable_digital ↔ dac, streamer, cd_transport, network`    | Digital Cables has no type attribute. `cable_interconnect_type` is analogue only (rca / xlr / din). Wants `cable_digital_type` (spdif_coaxial, toslink, aes_ebu, i2s, usb_b, usb_c, bnc, hdmi, ethernet) — the option keys already exist.                                                                                                                                                                                                                                                |
| `cable_speaker ↔ power_amp, integrated, speaker_*`        | `speaker_outputs` exists amp-side (binding posts / Speakon / spring clips); nothing describes the cable's termination. Wants `cable_speaker_termination` (banana, spade, bare wire, Speakon, BFA).                                                                                                                                                                                                                                                                                       |
| `tube_preamp ↔ dac`                                       | `amplifier_type` is not attached to DACs, so tube-output DACs cannot be identified. Either attach it to `dacs` or leave the edge out; the draft now leaves it out.                                                                                                                                                                                                                                                                                                                       |
| `cable_power ↔ everything`                                | No inlet type either side (IEC C7 / C13 / C15 / C19). Low value — mismatches here are rare and cheap.                                                                                                                                                                                                                                                                                                                                                                                    |
| `dac ↔ power_amp`, `dac`/`streamer` ↔ active loudspeakers | Nothing records whether a DAC or streamer has **volume control**. Without it, one that can drive a power amplifier or an active loudspeaker directly is indistinguishable from one that must feed a pre-amplifier first — and the ordinary chain is DAC → pre-amp → power amp. Wants a `volume_control` boolean on `dacs` and `streamers`.                                                                                                                                               |
| every `cable_interconnect` edge                           | Expressible in principle — `cable_interconnect_type` against `input_connectors` / `output_connectors` — but those two attributes sit at **0–1% coverage**, so the gate closed on every role they apply to while `switches`, which they are not attached to, rendered interconnects _ungated_ through the inapplicability rule. Interconnects appearing only on switch-box pages is worse than not appearing at all, so all of these edges are disabled until connector coverage is real. |
| `headphone → dac`, `headphone → integrated`               | Expressible, and now gated: these needed the mirror of `source_present`, so a **`target_present`** gate kind was added. `headphone_outputs` coverage is 0%, so the edges are quiet until someone fills the spec.                                                                                                                                                                                                                                                                         |

Until each gap is filled, the corresponding edge should ship **disabled** rather than
ungated. An ungated cable suggestion is not a softer version of a gated one; it is a
recommendation to buy the wrong connector.

### 5.4 Missing values decide how often this renders

`Completeness` already states that incomplete is the normal state, so the operative
question is what a gate does when its attribute is blank.

- **Shapes A and D: fail closed.** No value, no suggestion. A tube page that shows
  nothing is invisible; a tube page that shows every Class D amplifier is wrong in
  public and in a way readers notice.
- **Shape B: keep the edge, exclude unknown targets.** Its filter is a literal declared
  in the graph, independent of the source, so the edge is sound and only the
  unidentifiable candidates drop out.
- **Shape C: fail closed on an unfilled source.** Its filter is _read off the source_,
  so with no source value there is no criterion to filter targets by — "exclude unknown
  targets" is undefined. The only coherent alternatives are to drop the edge or to render
  it with no filter at all, which makes an unfilled source structurally identical to
  shape A. An unfilled cartridge paired with any phono stage is the same class of claim
  as an ungated cable: not a softer version of the gated one, a wrong one. Note that the
  inapplicability rule still applies first — a cross match none of whose source
  attributes are attached to the source's sub categories passes ungated.

The consequence is that the block stays hidden on most products until the gate
attributes are filled — which is the right failure mode, and turns those attributes
into the highest-value contribution targets on the site.

Four of the six are already `highlighted`, so they count toward completeness today:
`amplifier_type`, `loudspeaker_amplification_type`, `headphone_connection_type`,
`cartridge_type` / `supported_cartridge_types` / `cable_interconnect_type`.
**`headphone_outputs` is not highlighted** and probably should
be, given gate 6 depends on it. A contribution queue for "products whose
pairing gate is unfilled" falls out of `ContributeProductItem` with no new machinery.

---

## 6. Discontinued products

### 6.1 It is not a compatibility fact

Every gate in §5 answers "will these work together". `discontinued` does not: a
power amplifier withdrawn in 1982 drives a loudspeaker released in 2026 exactly as
well as it drove one in 1982. So it must not be modelled as a gate, and it cannot
be handled by the same mechanism.

It bears on _usefulness_, and usefulness splits by reader intent. A reader asking
"what should I buy to go with this" wants things still in production. A reader
asking "what was this designed to sit next to", or who already owns the thing,
does not — and hifilog has no marketplace, no prices to buy at and no affiliate
links, so the second reader is the one the site is actually built for.

### 6.2 What the catalogue looks like

|                                                      |                        |
| ---------------------------------------------------- | ---------------------- |
| products flagged discontinued                        | 665 of 1,133 — **58%** |
| median release year (of the 30% that have one)       | 1999                   |
| products with `release_year`                         | 349 — 30%              |
| products with `discontinued_year`                    | 193 — 17%              |
| discontinued products carrying a `discontinued_year` | 193 of 665 — 29%       |
| brands flagged discontinued                          | 206 of 2,231 — 9%      |
| brands with `discontinued` **unknown** (null)        | 955 — **42%**          |

Two conclusions follow, and both rule out the obvious designs.

**Excluding discontinued products removes 58% of the catalogue.** For a block that
is already short of candidates, that is not a refinement, it is a deletion.

**`products.discontinued` cannot assert that something is current.** The column is
`null: false, default: false`, so `false` means _either_ "confirmed in production"
_or_ "nobody has said" — there are 0 nulls across 1,133 rows because the schema
forbids them. `brands.discontinued` is nullable and 42% of brands sit in that
unknown state, which is the honest distribution. So the product flag can be trusted
when it says **true** and not when it says false, and no rule may depend on "this
product is current".

### 6.3 Rules

1. **Never filter on `discontinued`.** See above, in both senses.
2. **Label it.** The pairing block carries the same discontinued badge the product
   pages already use. This is the whole of the reader's problem: being _shown_ a
   withdrawn product is fine, being shown one _silently_ is not.
3. **Demote, mildly, in one direction only.** The case is asymmetric:
   - _Discontinued source → any companion._ No demotion. Someone who owns a vintage
     amplifier is precisely the reader who wants to know what current cartridge,
     tube or loudspeaker suits it. This is the most valuable direction in the
     feature and must not be degraded.
   - _Current source → discontinued companion._ A small ranking penalty, never
     exclusion.
4. **Guarantee one in-production candidate.** When the source is not flagged
   discontinued and any candidate in the target subcategory is also not flagged, at
   least one such candidate must appear. Without this, the fallback ordering
   (subcategory priority + completeness, §4) can produce an all-vintage lineup on a
   2026 product purely because well-documented classics score higher on
   completeness.
5. **Exempt the consumable roles from rule 3.** `tube_power`, `tube_preamp`,
   `tube_rectifier`, `cartridge` and `cable_headphone` carry no penalty. NOS tubes
   are the desirable end of that market, not the regrettable end, and demoting them
   would invert the advice.

### 6.4 Era, not the boolean

The failure worth avoiding is not "discontinued", it is anachronism: a 2026 flagship
suggesting something withdrawn in 1972. That is an _era_ question, and
`release_year` / `discontinued_year` answer it far better than the flag does —
overlapping market lifetimes, or a bounded gap between them.

Except that they are only present on 30% and 17% of products. So era is a **ranking
nudge applied where both sides have dates, and silent everywhere else** — never a
filter, or the 70% with no release year vanish. The consumable exemption in rule 5
applies here with more force: NOS tube and vintage cartridge pairings are maximally
anachronistic and entirely correct.

`discontinued_year` is missing on 472 of the 665 discontinued products, and that gap
is already one of the contribution queues. Era ranking improves as that queue is
worked, which is the right kind of dependency — it degrades to silence, not to
wrong answers.

### 6.5 Open question: should `products.discontinued` become nullable?

`brands.discontinued` is nullable and its completeness column scores
`discontinued IS NOT NULL` — the brand model can say "we do not know". Products
cannot, and as a result no surface can honestly claim a product is in production,
here or anywhere else on the site.

Making it nullable would let the contribution queues ask "is this still made?",
let the pairing block state in-production status rather than merely omit a badge,
and make rule 4 above expressible as written rather than as "not flagged". The cost
is a migration on a `null: false` column plus a pass over the view definitions and
the completeness expressions that read it. Worth deciding deliberately rather than
inheriting the current default by accident.

---

## 7. Ranking

### 7.1 Three stages, not one list

| Stage        | Question                     | Mechanism                                      |
| ------------ | ---------------------------- | ---------------------------------------------- |
| **Gate**     | may this be shown at all?    | binary; role edges (§2) + attribute gates (§5) |
| **Score**    | how good a suggestion is it? | weighted sum of normalised signals (§7.3)      |
| **Assemble** | what does the block contain? | diversity + guards (§7.5)                      |

Selection, ordering and set composition are separate problems. "Show one item per
subcategory" and "prefer the same brand" are not comparable rules and must not live
in the same list.

### 7.2 Use a weighted sum, not a priority order

A strict priority order — first co-occurrence, then possessions, then brand — hands
the entire ordering to whichever signal fires first. Given the data (§7.4), that
signal fires only at _n = 1_, so a lexicographic list systematically promotes the
single noisiest observation in the system and lets it outrank everything measured.
It maximises the influence of the evidence that deserves the least.

A weighted sum with per-signal normalisation to `0..1` avoids this. A signal with no
coverage contributes exactly zero rather than short-circuiting the comparison, and
the shift from "completeness decides" to "behaviour decides" becomes a change of
constants rather than a rewrite.

Damp the count-based signals by confidence rather than thresholding them:

```
score_cooccurrence = matches / (matches + k)      # k ≈ 5
```

One co-occurrence contributes 0.17 of the weight, twenty contributes 0.8. The signal
self-suppresses while thin and needs no special case. Keep a separate hard floor —
do not _display_ a co-occurrence claim below ~3 distinct users — because the ranking
question and the "N people run these together" claim are different questions.

### 7.3 Signals

| Signal                          | Kind           | Normalisation                    | Notes                                                     |
| ------------------------------- | -------------- | -------------------------------- | --------------------------------------------------------- |
| Co-occurrence in setups         | evidence       | `n/(n+k)`                        | strongest signal, zero coverage today                     |
| Co-occurrence in possessions    | evidence       | `n/(n+k)`, weighted below setups | owning both ≠ using together                              |
| Owner count of the candidate    | evidence       | percentile within subcategory    | denser than pairwise in principle                         |
| Bookmark count of the candidate | evidence       | percentile                       | weak intent signal, cheap                                 |
| Completeness                    | presentability | already `0..100`                 | a suggestion leading to an empty page is a bad suggestion |
| Has an image                    | presentability | boolean                          | card blocks live or die on this                           |
| Price proximity                 | fit            | `1 -                             | log(pa/pb)                                                | / c`, clamped | see §7.4 |
| Spec fit                        | fit            | per-rule, see below              | the real synergy                                          |
| Era proximity                   | fit            | §6.4                             | silent where dates are absent                             |
| Discontinued                    | fit            | penalty, one direction           | §6.3                                                      |
| Same brand                      | fit            | bonus, role-conditional, capped  | see below                                                 |
| Subcategory priority            | declared       | constant per edge                | carries the ordering today                                |

**Same brand is not a sort key.** Promoted globally it turns "what goes with this"
into the manufacturer's catalogue — which the reader can already reach from the brand
page — and it scales with brand size, so Denon, Sony and Yamaha monopolise every slot
while a brand that makes one category never benefits. It is also the signal most
likely to read as promotion.

It is genuinely strong in one place: components designed as a system. Turntable /
tonearm / cartridge, pre and power pairs, loudspeaker and matching subwoofer, amplifier
and its companion DAC. It is noise for cables, racks, tubes and isolation. So attach
the bonus to the _edge_, not to the scorer, and cap it at one same-brand item per
target subcategory.

**Spec fit is the feature hificafe only gestures at, and the attributes for it already
exist.** `amplifier_output_power` carries `ohm_8` / `ohm_4` facets; loudspeakers carry
`loudspeaker_recommended_amplifier_power`, `loudspeaker_minimum_impedance` and
`loudspeaker_sensitivity`. Headphones carry `nominal_impedance` and
`headphone_sensitivity` against `headphone_amplifier_output_power`. Treat it strictly
as a bonus where both sides are populated: wrong physics presented confidently is worse
than no physics, and an under-powered pairing is a judgement call, not a fact.

### 7.4 What is actually available

| Signal                       | Coverage                                                      |
| ---------------------------- | ------------------------------------------------------------- |
| Co-occurrence in setups      | 8 setups, 22 memberships — max co-occurrence **1**            |
| Co-occurrence in possessions | 127 products owned, **max 2 owners**, only 2 products with ≥2 |
| Owner / bookmark counts      | effectively flat — see above                                  |
| Has an image                 | 16 of 135 possessions carry a highlighted image               |
| Price                        | **126 of 1,133 (11%)**, in USD / EUR / GBP with no conversion |
| Era                          | `release_year` 30%, `discontinued_year` 17% (§6.2)            |
| Discontinued flag            | 100% populated, but `false` is not assertable (§6.2)          |
| Completeness                 | 100%, computed in SQL                                         |
| Same brand                   | 100%                                                          |
| Subcategory priority         | 100%, declared here                                           |

Both signals at the top of the proposed list are empty, and so is the obvious
fallback of candidate popularity. **Today the ordering is subcategory priority, then
completeness, then a stable tie-break** — and every other signal is a weight sitting
at zero. That is a reason to build the scorer with the weights externalised, not a
reason to build a simpler scorer.

Price deserves attention before it is usable: three currencies with no FX, and a
vintage catalogue where a 1978 MSRP is not comparable to a 2026 one. Decide whether
the stored price is nominal-at-release or present-day equivalent before ranking on
it, or the 58% discontinued half of the catalogue will read as uniformly cheap.

### 7.5 Assembly

- Cap at ~4 target subcategories per page, ~3 products each (§4).
- Fill subcategories round-robin by declared priority before deepening any one, so a
  page never shows four cables and no amplifier.
- At most one same-brand item per subcategory.
- Guarantee one not-discontinued candidate where any exists (§6.3, rule 4).
- Hide a subcategory entirely rather than pad it with a single poor candidate.

### 7.6 Performance

Do not score at request time.

Everything product-level — completeness, owner count, image presence, price band, era,
discontinued — is stable between writes and belongs in precomputed columns or the
existing catalogue views, alongside the completeness expression that already lives in
`contribute_product_items`.

Only three terms depend on the pair, and all three are cheap: same brand is an
equality, price proximity is arithmetic on two precomputed bands, and co-occurrence is
a lookup in a materialised view bounded to role-adjacent pairs — which is what keeps
that view from being O(products²). Refresh it concurrently on a nightly job.

The §5 gates stay as request-time `WHERE` clauses on `products.custom_attributes`;
they are already covered by `index_products_on_custom_attributes` and precomputing
them would be quadratic in the catalogue for no gain. One indexed query per block.

---

## 8. Corrections from review

**`switches` is not network gear.** The sub category sits under Accessories: A/B boxes that select
between two amplifiers, or between two pairs of loudspeakers. The role was originally modelled as
`network` and paired with streamers and DACs, which was wrong in both directions. It is now
`switch_box`, pairing with power amplifiers, integrated amplifiers, pre-amplifiers, passive
loudspeakers, loudspeaker cables and interconnects, with reverse edges on the three amplifier roles
at the accessory end of their priority lists. Nothing distinguishes a speaker-level box from a
line-level one — neither `input_connectors` nor `output_connectors` is attached to that sub
category — so both readings share one edge list.

**References are to identifiers, and the models defend them.** The graph originally named sub
categories by `slug`, which FriendlyId regenerates whenever the name changes — so renaming
"Bookshelf & Standmount Loudspeakers" for clarity would have silently emptied every edge pointing
at it, with nothing but `related_products:check` to notice. `SubCategory` now carries a separate
`identifier`, derived from the name once and immutable thereafter, and the graph references that.
`CustomAttribute` refuses to rename or delete a label, or remove an option key, that a gate names.
Detection became prevention for the two classes where it was possible; the third — a sub category
created with no role at all — is a completeness problem no storage choice fixes, because a new sub
category needs _edges_, and only code can supply those.

**A presence gate whose predicate is near-universal can only subtract.** Gate 7 —
`power_amp` / `integrated` → loudspeakers, conditioned on `speaker_outputs` being present — was
removed. Practically every power amplifier, integrated amplifier and receiver has speaker
terminals, so the predicate was true of almost every member of those sub categories and could
never exclude a wrong suggestion; meanwhile the attribute was filled on 0 of 267 amplifier
products, so it hid loudspeakers from every amplifier page. `headphone_outputs` looks similar and
is kept, because it genuinely discriminates: plenty of integrated amplifiers and DACs have no
headphone socket. The test for a presence gate is whether its predicate is ever false within the
sub categories it applies to. `speaker_outputs` survives as an attribute — the speaker-cable
termination gap in §5.3 still wants it.

**Directness.** An edge must not skip a link in the signal chain. The review that produced the two
new §5.3 rows applied that test to all 35 roles; what survived it, deliberately, is the set of
edges that are real pairings without being signal connections — a subwoofer beside loudspeakers
(both connect to the amplifier, not to each other), and the racks, isolation, power cables and
power conditioning at the tail of every component role. Those sit last in priority and rarely
render.
