# Custom attribute qualifiers

Status: **implemented.** `loudspeaker_sensitivity` is migrated (§3). `headphone_sensitivity` keeps
its single unit until a dB/V value has to be recorded, and §3.3 says why. This document holds the
reasons for the design and the decisions behind it. For the mechanism as it works now, see
[custom-attributes.md, §5](custom-attributes.md#5-qualifiers).

Two definitions still need their conditions set in ActiveAdmin, because they are data rather than
code and the bulk task does not declare them: `frequency_response_range` (§6.1) and
`loudspeaker_peak_spl`.

---

## 1. The problem

A `CustomAttribute` of input type `number` holds a number, a `unit` and, if the definition
declares `inputs`, one number per input. Some specifications need one more piece of information:
the condition under which the number was measured.

The example that started this: `frequency_response_range` is meaningless without the tolerance
it is quoted at. "20 Hz to 20 kHz" at ±3 dB is a much stronger claim than the same range at
±6 dB. The catalog cannot record the difference today, so the two figures are stored as if they
were the same fact.

The condition is **often absent** from the source material. It must stay optional.

---

## 2. The new dimension

A **qualifier** describes one value. It is a third axis, parallel to `unit`.

Keep the three axes apart:

| Axis        | Effect on the value                | Example                            |
| ----------- | ---------------------------------- | ---------------------------------- |
| `unit`      | Changes the scale of the number    | `kg` and `lb`                      |
| `inputs`    | Gives one number per facet         | `w` / `h` / `l`, `ohm_8` / `ohm_4` |
| `qualifier` | States how the number was measured | ±3 dB, at 1% THD, A-weighted       |

### 2.1 The test that decides which axis to use

The test is what the product form does with the distinction.

> `inputs` is a **request**. It is a small, fixed set of operating points that the catalog asks
> for in each case, and the form shows one field for each of them.
>
> A qualifier is a **description**. It is the convention that belongs to the one figure that the
> source gives.
>
> To decide, ask if the catalog wants to collect each combination. If yes, use `inputs`. If the
> answer is no, because most sources give one figure only, use a qualifier.

Do not use the test "can both values be true at the same time". It gives the wrong answer: a
brand can give power at 0.1% THD **and** at 1% THD, and both figures are true, but the catalog
must not ask each amplifier for three figures that almost no source gives.

Examples:

- Width, height and length. The catalog wants all three for each product. This is `inputs`.
- Power into 8 Ω and into 4 Ω. The catalog wants both for each amplifier. This is `inputs`, which
  is what `amplifier_output_power` does.
- Power at 0.1%, at 1% and at 10% THD. Most sources give one of these, so fields for all three
  collect empty values. This is a qualifier.
- A nominal impedance and a minimum impedance. The catalog wants both for each loudspeaker. It
  correctly holds them as two attributes, `nominal_impedance` and
  `loudspeaker_minimum_impedance`. Do not change them into qualifiers.
- An RMS power rating and a peak power rating. The catalog wants both. It correctly holds them as
  `loudspeaker_rms_power` and `loudspeaker_peak_power`. Do not change them into qualifiers.

### 2.2 Name

Use `qualifiers` for the array on the definition and `qualifier` for the string in the stored
entry. The singular and plural pair is the same shape as `units` and `unit`, so a reader who
knows how units work can read this without more explanation.

Do not use `condition`. In this application, "condition" is about the state of a used item.
Do not use `tolerance`. It fits ±3 dB and nothing else in the list in §6.

### 2.3 Rejected alternatives

- **More `inputs`.** Frequency response at ±3 dB and at ±6 dB as two facets. This is wrong by the
  test in §2.1, and the product form would ask a contributor for both numbers.
- **One attribute for each condition**, for example `frequency_response_range_3db`.
  [custom-attributes.md](custom-attributes.md#2-naming-a-label) (§2 and §2.2) already refuses this
  shape: it splits one attribute along a distinction that its values carry,
  it makes two filter facets that hold the same numbers, and the two can then never be compared.
- **More `units`.** This is what `loudspeaker_sensitivity` does today, and §3 explains why it
  must stop.

---

## 3. The definition this repairs, and the one it does not

`loudspeaker_sensitivity` declares two units, `db_1w_1m` and `db_283v_1m`. These are not two
units. They are one unit, dB, with two measurement conditions. Because a definition may declare
two units only when `CustomAttribute::UNIT_CONVERSIONS` pairs them, the display path in
`app/views/shared/_product_custom_attributes.html.erb` carries a special case for this pair, and
`UNIT_CONVERSIONS` carries a comment that explains it.

`loudspeaker_sensitivity` now holds `db` as its single unit, with `drive_1w_1m` and
`drive_283v_1m` as qualifiers. The migration
`MoveLoudspeakerSensitivityToQualifiers` rewrote the definition and its values in one transaction.

### 3.1 Rejected: calculate dB per volt on write

A value in dB per volt converts to dB per milliwatt with the impedance of the product:

```
dB/V = dB/mW + 10 * log10(1000 / Z)
```

The arithmetic is correct, and `nominal_impedance` holds Z for most headphones. Do **not** use it
to normalize the value on write.

`CustomAttribute::UNIT_CONVERSIONS` works because each factor is constant for all time. This
factor is not. It comes from a different attribute of the same product. If a contributor corrects
`nominal_impedance` later, each sensitivity value that was normalized with the old impedance
becomes wrong, and the figure that the source printed is gone. An edit of one attribute must not
silently damage another.

Use the formula for **display** instead: keep the figure of the source with its qualifier, and
show the second reading when the impedance is known. This keeps the original value.

### 3.2 Requirements of the migration

The migration derives the qualifier from the old unit only where that unit was **evidence**. §4.1's
"never write a default" binds here as everywhere else, and one of the two old units was partly a
default.

| Old unit     | Where it came from                                                                                                                                                | Result                              |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| `db_283v_1m` | Always evidence: the form's radios start unselected, and `specs.py` needed a 2.83 V marker                                                                        | `db` + `drive_283v_1m`              |
| `db_1w_1m`   | Evidence from the form; from the importer, a fallback — `specs.py` ended `else "db_1w_1m"`, so a sheet stating nothing got the same answer, which is most of them | `db` + `drive_1w_1m`, or `db` alone |
| absent       | Not evidence. The display's `units.first` fallback shows a condition nobody entered                                                                               | no unit, no qualifier               |

For `db_1w_1m` a **snippet decides**, where one exists. `import_candidates` keeps the source line in
`provenance -> 'custom_attributes.loudspeaker_sensitivity' ->> 'snippet'`:

- A **candidate** gets the qualifier only when its snippet names a watt reference. No snippet means
  no evidence, because every candidate unit came from `specs.py`.
- A **product** gets the qualifier unless the candidate it was promoted from has a snippet naming no
  watt reference. The test is negative on purpose: a product with no candidate was entered through
  the form, and absence of a candidate is not absence of evidence.

`down` is therefore not exactly `up` reversed. A row that held the `db_1w_1m` fallback comes back
with no unit, because restoring it would put back an assumption — and would put it on rows that
never carried one.

The migration must also do these things:

- **Keep the `db_1w_1m`, `db_283v_1m` and `db_mw` translations** under `custom_attribute_units`.
  `app/views/shared/_changelog.html.erb` and `app/presenters/admin_version_activity_presenter.rb`
  render units from old PaperTrail versions. If the keys go, the history of each product shows
  "translation missing".
- **`SimilarProducts::Query` needs no change, and this was checked rather than assumed.** An
  earlier version of this document said `unit_sql` keeps a 1 W at 1 m figure apart from a 2.83 V at
  1 m figure, and that a `qualifier_sql` had to replace that function. That is wrong.
  `unit_sql` runs only for the attributes in `SimilarProducts::Weights::NUMERIC_CLASSES`, and
  sensitivity is deliberately not one of them: it is too specific to one product to make two
  products similar. The scorer never read the sensitivity unit, so it loses nothing.

  The qualifier stays out of the score for now, for the reason in §7: a missing condition scores 0
  rather than a penalty, and to treat a ±3 dB figure as equal to a ±6 dB one is a small error
  against low coverage.

- **`import_candidates` is rewritten too.** A candidate holds `custom_attributes` of the same
  shape, and `ImportPromotion` copies them into the new product verbatim. A candidate extracted
  before the migration would otherwise promote into a product carrying a unit its definition no
  longer offers, which no filter can reach. See §3.4 for the durable fix that goes with it.
- **`down` removes a `db` unit it cannot invert.** An entry left with `db` and no qualifier has no
  old unit to go back to: either the importer wrote it, or somebody entered it after the migration.
  The unit key is removed rather than guessed, which is what an unqualified value looked like
  before.
- **Old filter URLs stop matching, and that is accepted.** A link that holds `unit=db_1w_1m` no
  longer matches, and there is no redirect for a filter parameter today. These links are not
  bookmarked, so no compatibility work was necessary. Do not build a redirect.
- **A value with no unit keeps no qualifier.** One production value had no unit. The migration
  leaves it unqualified, and the condition is entered by hand in the product form if a source
  states one.

### 3.3 Why `headphone_sensitivity` is not migrated

`headphone_sensitivity` looks like the same case, and it is not, because it declares `db_mw`
**only**. The other convention in use is dB per volt, which does not convert to dB per milliwatt
without the impedance of the product — but no stored value uses it, so nothing is wrong today.

The pair test in the display path and in `entity_form.js` reads `units.size == 2`, so a definition
with one unit never reaches it. Migrating `loudspeaker_sensitivity` alone therefore removed the
whole problem. To migrate `headphone_sensitivity` as well would be to invent a qualifier dimension
that no value uses.

Do it when a dB/V value has to be recorded, not before. The change is then the same shape as §3.2:
one unit `db`, two qualifiers, and a rewrite of the stored entries from `db_mw`.

### 3.4 Where an imported unit comes from

The importer has two paths, and only one of them wrote the catalogue's data.

**`specs.py` reads the unit from the text.** It parses a spec sheet line by line: it converts
grammes to kilogrammes and millimetres to centimetres, and keeps pounds as pounds. For sensitivity it
read the drive reference out of the line and wrote it as the unit, `db_283v_1m` or `db_1w_1m` — but
its `else` branch meant a line stating **no** reference also came out as `db_1w_1m`. So an imported
`db_283v_1m` is evidence and an imported `db_1w_1m` may not be, which is what §3.2 acts on.

**`extract_text.py` takes `units.first`.** `_clean_attribute` reads
`(definition.get("units") or [None])[0]` for a figure the language model returned, without reading
the unit from the text. This path is a fallback and shows no trace in the data checked below. It is
still wrong, and it is the thing to fix if that path is ever used for a definition with two units —
`weight` lists lb first, so a kilogramme figure would be stored as pounds and then converted.

**What the production candidates say**, checked against the source snippet each one kept, for the
three definitions that offer two units:

| Definition                | Stored units         | Agreement with the source snippet                                                                       |
| ------------------------- | -------------------- | ------------------------------------------------------------------------------------------------------- |
| `weight`                  | kg and lb, both used | Every value agrees with its snippet; grammes convert to kg                                              |
| `dimensions`              | cm and in, both used | Agrees; millimetres convert to cm                                                                       |
| `loudspeaker_sensitivity` | both units used      | Every `db_283v_1m` has the 2.83 V marker; only a small minority of the `db_1w_1m` name a watt reference |

So there is no silent conversion error in the catalogue, and no repair task is needed. The last row
is the reason `db_1w_1m` alone is not treated as evidence (§3.2).

To check this again after the data has changed, read the entry beside
`provenance -> 'custom_attributes.<label>' ->> 'snippet'` for the candidates that hold each label.

#### Two changes to `parse_sensitivity`

**It now emits a qualifier, not a unit — and three outcomes, not two.** This is the change the
migration makes necessary, and without it the importer would be the one path that still writes the
old spelling:

```python
entry = {"value": _tidy(amount), "unit": "db"}
if voltage:
    entry["qualifier"] = "drive_283v_1m"
elif watt:
    entry["qualifier"] = "drive_1w_1m"
```

The third outcome is the one the old code did not have. `"89 dB"` states no reference, and most
sheets do not — in the production candidates the large majority name none. `else "db_1w_1m"` gave
every one of them the same answer, so the catalogue claimed a measurement condition nobody
published, and a filter on "At 1 W / 1 m" would have returned them. A qualifier is optional by
construction, so the honest answer is to leave the key out.

Leaving it as a unit would have lost the condition **in silence**, which is the worst shape of this
bug. The definition offers `db` alone after the migration, so `prune_unsupported_keys` drops
anything else on promotion, and nothing sets a qualifier in its place. In the admin the candidate
would still look right, because the old unit translations stay in `en.yml` for the changelog (§3.2).
The figure would reach the catalogue, the condition would not, and no warning anywhere.

The `headphone_sensitivity` branch keeps `db_mw` as a unit: that definition is not migrated (§3.3).

**It now reads the label as well as the value.** The reference is as often in the label, and only
the value side was searched:

```
Sensitivity (2.83Vrms/1m): 84dB   →  stored db_1w_1m
Rendement (2.83V): 96dB           →  stored db_1w_1m
```

A small number of candidates were stored as the watt fallback for this reason. The migration
corrects them from their own snippet (§3.2), so no list of ids is needed. Only the reference test
reads the label — the milliwatt test and the range guards stay on the value, where a stray word
in a label cannot change which number is stored. A line stating both references, such as
`97dB SPL @ 1W/1m (using input 2.83 rmsV)`, keeps the 1 W reading: 2.83 V into 8 ohms is 1 W, so the
two do not contradict each other, and the sheet's headline beats a guess about which half it meant.

The two changes belong together. The label fix alone would have found the voltage reference
correctly and then written it in a spelling the application throws away.

**The lasting protection** against a wrong unit or condition reaching the catalogue is
`CustomAttribute.prune_unsupported_keys`, called from `Product`'s `before_save` beside
`normalize_units`. It sits on the model and not in the products controller, because
`ImportPromotion`, ActiveAdmin, `ProductConversionService` and the console are write paths too, and
the controller sees none of them. It cannot fix a unit that is wrong but offered — only one the
definition does not know.

**`bin/rails import:schema` must be re-run** after the migration. The exported schema is what the
extractor reads, and a stale copy still lists `db_1w_1m` and `db_283v_1m` as the units of
`loudspeaker_sensitivity` and names no qualifiers.

---

## 4. Data model

### 4.1 Stored value

```jsonc
"frequency_response_range": {
  "value": { "min": 20, "max": 20000 },
  "unit": "hz",
  "qualifier": "db_3"
}
```

The key is absent when the condition is not known. An absent key means "not stated". Never write
a default value. A definition must not declare a fallback qualifier, because an assumed condition
is invented data.

`CustomAttribute.normalize_units` merges only `value` and `unit`, so a qualifier survives it. No
change is needed there.

### 4.2 Definition

Add a `qualifiers` string array column to `custom_attributes`, with `default: []`, in the same
shape as `inputs`. No backfill is needed.

**Do not add `null: false`.** The `units` and `inputs` columns do not have it, and a different
shape for the third column of the same kind is a difference with no reason. It also has a cost:
the null constraint makes the null-constraint checker of `database_consistency` ask for a presence
validation, and `presence` on an array that defaults to `[]` rejects each definition that declares
no qualifier, because `[].present?` is false. This is the same trap that the comment about
`highlighted` in `CustomAttribute` describes. With no null constraint,
`.database_consistency.yml` needs no change.

Add a `VALID_QUALIFIERS` constant beside `VALID_UNITS` and `VALID_INPUTS`. The set of qualifiers
is code, not data, for the same reason that inputs are code: the set is small, it is shared
between attributes, and a constant can be checked by a test. `CustomAttributeTest` must assert
that each entry has a `custom_attribute_qualifiers` translation, as it does for units and inputs.

Add a `qualifiers_must_be_valid` validation in the same shape as `inputs_must_be_valid`. Report
the error against `:qualifiers`, so the admin form shows it beside the correct field group.

### 4.3 Which input types may declare qualifiers

Only `number`. The `before_validation` that clears configuration which the current input type
does not use must also clear `qualifiers` for every other input type. This keeps the rule that
exactly one shape of extra configuration applies for each input type.

### 4.4 One qualifier for each entry

An entry holds one `qualifier`, in the same scope as its one `unit`.

**Not one for each input.** An amplifier states both of its power figures at the same distortion,
so a qualifier for each input has no use, and it would add a level of nesting that nothing else in
the JSON has.

**One dimension of values for each definition.** Because an entry holds one qualifier, the
`qualifiers` array of a definition must hold values that exclude each other. A list that mixes two
dimensions cannot be stored: "1% THD" and "both channels driven" are both true of one figure, and
"at 1 m" and "one pair" are also both true of one figure. Two other solutions exist and are
rejected:

- **Combined keys**, for example `thd_1_both_channels`. The number of keys multiplies, and most of
  the combinations never occur.
- **An array of qualifiers for each entry.** This breaks the pair with `units` and `unit` that the
  name rests on, and it makes each filter condition a set operation.

So a definition declares one dimension. Where a second dimension has a use, leave it out of scope
for now. §6.1 shows which values this removes.

**Accepted limit: one figure for each product.** A source that gives the same specification under
two conditions loses one of the two figures. The catalog has one entry for each attribute, and
this design does not change that. The contributor rule follows: **when a source gives more than
one condition, record the figure at the tighter condition** — ±3 dB before ±6 dB, 1% THD before
10% THD. The catalog is then careful in one direction instead of mixed. Put this rule in the
contribution guidelines.

### 4.5 Namespace

Qualifier keys are in one flat namespace, as option values are. The rule from
[custom-attributes.md, §2.1](custom-attributes.md#21-option-values) applies without change: share a key when two attributes mean the same thing by it, and prefix a key when
two attributes only share a word. `a_weighted` is the same condition for a signal-to-noise ratio
and for rumble, so spell it once.

### 4.6 Scoping by sub category

Do not add scoping by sub category, as `custom_attributes_sub_categories.option_ids` does for
options. An attribute that needs different conditions in different sub categories is usually two
attributes. Add the scope later if a real case appears.

`frequency_response_range` was the case to watch, because it spans sub categories in three groups
with different conventions (see §6.1). The decision is made: **do not scope it.** The union
of the conventions is seven values, which is a list a contributor can read. Scoping would also need
a new column on `custom_attributes_sub_categories`, because `option_ids` scopes options only.

### 4.7 What the write path does

Nothing in the database constrains `unit` or `qualifier`, and the product form permits
`custom_attributes: {}`, an open hash. `discard_unknown_custom_attributes!` in
`app/controllers/products_controller.rb` removes a label that no definition backs, and
`coerce_number_custom_attribute!` reads `value` only. Neither looks at the other keys of an entry.

`CustomAttribute.prune_unsupported_keys` does, and it does two things:

- **Deletes a blank qualifier.** The control for the state "not stated" must be able to clear a
  qualifier that was set before, so it posts an empty string. Stored, the entry gets
  `"qualifier": ""`, which breaks §4.1: `? 'qualifier'` is then true for a condition that is not
  there, so every reader of a qualifier has to treat the empty string as a third case.
- **Deletes a `unit` or `qualifier` the definition does not declare.** The same rule as
  `discard_unknown_custom_attributes!` applies to an unknown label, and for the same reason: a
  value that no definition knows can be displayed, filtered or scored by nothing. A wrong unit is
  worse than untidy — filtering compares the stored unit string, so the figure becomes unreachable.

  A definition that declares **no** units is the exception: it says nothing about units, the filter
  applies no unit predicate for it, and `normalize_units` needs the stored unit to convert from, so
  the unit stays. A definition with no qualifiers is not an exception — it asks no question, so a
  stored condition is not an answer to one, and it would still print on the product page.

**It belongs on the model, not in the controller.** `Product` calls it in `before_save`, beside
`normalize_units` and before it, so an unknown unit is dropped rather than used as the basis of a
conversion. The controller is the wrong place because it is not the only write path:
`ImportPromotion` copies a candidate's specs verbatim and never renders a form, ActiveAdmin and
`ProductConversionService` write products too, and so does the console. §3.4 is the case that makes
this necessary rather than tidy.

---

## 5. Filtering

### 5.1 The failure to avoid

Do not filter a qualifier as `unit` is filtered. `ProductFilterService` compares a submitted unit
for equality, and that is safe only because values are normalized on write. A qualifier cannot be
normalized, because no factor exists between two conditions. Coverage will also start near zero.
Strict equality would therefore return almost no rows. The related-product gates already show
this failure: most gated edges do not render, because the attributes they read are not filled in.

### 5.2 The behavior

The qualifier is a separate, optional facet with **two states**. The visitor opts into it.

1. The `min` and `max` range controls work exactly as before. They never read the qualifier.
2. A second control for each attribute shows the qualifiers that the definition declares.
3. **Nothing selected adds no condition to the query.** This is the behavior from before the
   facet existed, so low coverage can never make a filter worse than it was.
4. One or more selected restricts the result to entries whose qualifier is in that set. A figure
   whose condition nobody recorded is therefore **not** a match.

#### There is no "not stated" option

An earlier version of this design had a third state: a "not stated" checkbox that also kept the
entries with no qualifier. It was removed before it was used, because it earns too little.

The box expressed one query and no other: _this condition, or none recorded_ — keep the figures
measured tightly and the figures that say nothing, but drop the ones known to be measured loosely.
That is a coherent question, and nobody is likely to ask it. A visitor who cares enough about the
condition to open the facet usually wants the strict answer; a visitor who does not care leaves the
facet alone and gets everything. The middle position is served well enough by selecting nothing,
which returns a superset, so the absence of the box leads nobody into an empty result.

Against that, the box cost three things:

- A reserved value in the parameter space that is not a qualifier, and a test to keep a future
  qualifier from colliding with it.
- The one branch a containment test cannot answer. Every other branch is `@>`, which the GIN index
  serves; "not stated" is a negated `?`, which it does not. Each query therefore mixed an indexed
  test with an unindexed one.
- A third state for a reader of the sidebar to reason about.

The "or better" refinement of §9 points the same way: it makes the strict selection more useful,
which shrinks the case for a control whose only purpose is to loosen the query.

**The product form keeps its "Not stated" option.** That control has a different job: a contributor
who learns that a source states no condition must be able to clear a qualifier that was set before,
and a radio group cannot return to unset. Only the filter checkbox was removed.

### 5.3 SQL

For one selected qualifier, prefer containment:

```sql
custom_attributes @> '{"frequency_response_range":{"qualifier":"db_3"}}'::jsonb
```

The GIN index on `products.custom_attributes` serves `@>`. It does not serve a comparison with
`->>`. For more than one selected qualifier, use an `OR` of containment tests, which the index
still serves.

Every branch is therefore indexable, which is the second reason the "not stated" option is absent:
it is the only condition of this facet that a containment test cannot express.

A row that has no value for the attribute at all matches nothing, which is correct. The predicate
needs no extra test for the label.

---

## 6. Where to use this

### 6.1 Definitions that exist and need a qualifier

Each list holds one dimension only, as §4.4 requires.

| Label                              | Dimension       | Qualifiers                                       |
| ---------------------------------- | --------------- | ------------------------------------------------ |
| `frequency_response_range`         | tolerance       | ±1 dB, ±2 dB, ±3 dB, ±6 dB, −3 dB, −6 dB, −10 dB |
| `loudspeaker_sensitivity`          | drive reference | at 1 W / 1 m, at 2.83 V / 1 m — done, see §3     |
| `headphone_sensitivity`            | drive reference | per mW, per V — not yet, see §3.3                |
| `amplifier_output_power`           | distortion      | at 0.1% THD, at 1% THD, at 10% THD               |
| `headphone_amplifier_output_power` | distortion      | the same as above                                |
| `loudspeaker_peak_spl`             | distance        | at 1 m, at 2 m                                   |

Six of the definitions that exist today need this. Two of those six are the repair in §3.

Two values are out of scope because they are a second dimension, not because they have no use:

- **"both channels driven"** for the two power definitions. It is a condition of the test, not a
  distortion figure. Few sources state it.
- **"one unit" and "one pair"** for `loudspeaker_peak_spl`. This is a count, not a distance. The
  contribution guidelines must say which one the catalog means, in the same way as for `weight`
  (§6.3).

#### The tolerance list, and where it comes from

`frequency_response_range` is attached to sub categories in three groups. Each group has its own
conventions, and the list above is their union:

| Group         | Sub categories                                                                                                                                     | Conventions in use                                                                                        |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Analog source | Cartridges, Tape Decks                                                                                                                             | Tight two-sided tolerances: ±1 dB, ±2 dB, ±3 dB                                                           |
| Headphones    | In-Ear Monitors, Noise Cancelling Headphones, On-Ear Headphones, Over-Ear Headphones                                                               | Most sources state no tolerance at all; ±3 dB where one is stated                                         |
| Loudspeakers  | Bookshelf & Standmount Loudspeakers, Center Channel Speakers, Floorstanding Loudspeakers, In-Ceiling, In-Wall and On-Wall Loudspeakers, Subwoofers | Two-sided ±3 dB and ±6 dB; one-sided −3 dB, −6 dB and −10 dB for the low corner, above all for subwoofers |

Three consequences:

- **Seven values, one list.** §4.6 records the decision not to scope the list by sub category.
- **The headphone group is the argument for optionality.** Most headphone sources give a bare range
  with no tolerance. If the qualifier were ever made necessary, or counted for completeness, this
  group alone would produce empty fields on most products.
- **A tape deck states its frequency response per tape type**, for example "30 Hz to 19 kHz ±3 dB
  with Type II". The tape type is a second dimension, which §4.4 does not allow in one list. Keep
  the tolerance in the qualifier and leave the tape type out: which types a deck accepts is a
  property of the deck, so it belongs in an `options` attribute of its own, not in the condition of
  one figure.

**A tolerance that the list does not hold.** If a source states, for example, ±2.5 dB, leave the
qualifier not stated. Do not move the value to the nearest entry in the list: the figure would then
claim a condition that nobody measured. Add the value to `VALID_QUALIFIERS` when it occurs more than
one time.

### 6.2 Definitions that do not exist yet

Most of the value of the mechanism is in specifications that the catalog does not hold yet. If
these are added later, each one needs a qualifier from the start:

signal-to-noise ratio (A-weighted or unweighted — often 10 dB apart), total harmonic distortion,
wow and flutter (WRMS, DIN or JIS), rumble, channel separation, dynamic range, cartridge output
voltage (at 5 cm/s or at 3.54 cm/s), battery life (noise cancelling on or off).

### 6.3 Do not add a qualifier to these

`weight` and `dimensions`. Net or shipping weight, and one unit or one pair, are exclusive
conditions, so they pass the test in §2.1. But a rule in the contribution guidelines that states
which one the catalog means is cheaper, and it gives the contributor one less field. A filter
facet for this has no use.

---

## 7. Effects on other parts of the application

- **Completeness.** The qualifier must not count. It is optional, so counting it would reduce the
  score of every product at the same time, and the contribution queues would reorder in one step.
  This is the same risk that the comment about `highlighted` in `lib/tasks/custom_attributes.rake`
  describes.
- **`SimilarProducts::Query`.** Ignore the qualifier for now: the score compares numbers in
  classes, and to treat a ±3 dB figure and a ±6 dB figure as equal is a small error, while a
  missing value already scores 0 instead of a penalty. This answer changes with the migration in
  §3 — read §3.2, which says why `unit_sql` then needs a `qualifier_sql` beside it.
- **`RelatedProducts::Graph`.** A gate must never read a qualifier. A measurement condition is not
  a fact about compatibility. The guards that protect a gated label and a gated option key need no
  equivalent for qualifiers.
- **`app/assets/javascripts/entity_form.js`.** The unit radio buttons convert the number that is
  shown, because two units are two spellings of one value. A change of the qualifier must not
  convert the number: a different condition is a different measurement, so the number stays as the
  contributor typed it. The selector for the converter reads
  `input[type="radio"][name$="[unit]"]`, so a control named `[qualifier]` does not start a
  conversion and no new code is necessary. **Add a test that keeps this true.** The whole
  protection is one string at the end of a selector.
- **Product form.** Add one control beside the unit radio buttons. Its default state is "not
  stated", and that state must be selectable again after a qualifier was set — see §4.7 for what
  the server does with the empty value it posts.
- **`rake custom_attributes:define`.** Add `qualifiers` to the declaration hash and to the
  comparison that decides if a definition changed.
- **ActiveAdmin.** Add `qualifiers: []` to `permit_params` of the `CustomAttribute` resource, next
  to `units: []` and `inputs: []`, and add the field group to the form.
- **Import.** `bin/rails import:schema` must export `qualifiers` beside `units` and `inputs`. The
  importer in `tools/brand_importer/` needs a rule for the condition that a source states in text,
  for example "20 Hz – 20 kHz (±3 dB)". See [import.md](import.md).

### 7.1 Each place that shows a value

Show the qualifier in parentheses after the reading, for example `20 Hz – 20 kHz (±3 dB)`. Where a
second unit reading is shown, put the qualifier after both readings. Five places render a value
today and each one needs the qualifier:

| Place                                                  | Note                                                                                                                  |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `app/views/shared/_product_custom_attributes.html.erb` | The characteristics list on the product page and the variant page.                                                    |
| `app/views/shared/_product_item.html.erb`              | The product card in lists.                                                                                            |
| `app/views/shared/_changelog.html.erb`                 | Without the qualifier, a change of the qualifier alone shows the same text before and after, so the entry looks void. |
| `app/presenters/admin_version_activity_presenter.rb`   | The same problem in the admin activity list.                                                                          |
| `app/admin/import_candidates.rb`                       | The candidate view, which a reviewer reads before the data goes into the catalog.                                     |

## 8. Order of work

1. Add the `custom_attribute_qualifiers` translations. A definition cannot name a qualifier before
   its translation exists, which is the same order that labels impose.
2. Add the column (§4.2), the `VALID_QUALIFIERS` constant, the validation, the clearing of the
   field by input type, and `qualifiers: []` in the ActiveAdmin permitted parameters.
3. Add the admin control, the product form control, the write path steps of §4.7, and the five
   display places of §7.1.
4. Add the filter control and the query.
5. Add `qualifiers` to `frequency_response_range` and to the other definitions in §6.1, except the
   two in §3. Read the sub categories of `frequency_response_range` first.
6. Done: `loudspeaker_sensitivity` moved from units to qualifiers, by the migration of §3.2. There
   was no special case to delete in the display path — the pair test there is generic, and only the
   comments named sensitivity as the reason for it. `headphone_sensitivity` is still to do, when a
   dB/V value needs recording (§3.3).

---

## 9. A later refinement, and why no data change is needed for it

For some attributes the qualifiers have an order of strictness. ±1 dB is a stronger claim than
±3 dB. The question that a user asks is therefore "at ±3 dB **or better**", not "at exactly
±3 dB".

The declared order of the `qualifiers` array can carry this, in the same way that the order of the
`options` hash carries the curated order of option values. The filter can then show a selection of
"or better" instead of check boxes, for definitions whose qualifier list has an order.

Build the set membership filter of §5 first. This refinement changes only how the filter is
rendered and how the query is built. It needs no change to the stored entries.

---

## 10. Documentation

One row for this document is already in the table in `README.md`. Each file in `docs/` has a row
there, so the row exists from the day the file exists, not from the day the feature works.

When the feature is implemented, update these:

- **[custom-attributes.md](custom-attributes.md)**: add the third axis and the test from §2.1.
  Keep it short.
- **[contribution-guidelines.md](contribution-guidelines.md)**: what a contributor does when the
  source states no condition, the rule of §4.4 for a source that states more than one condition,
  and the rules for `weight`, `dimensions` and the count for `loudspeaker_peak_spl` (§6.1, §6.3).
- This document: change the status line, and change it from a proposal into a description of the
  mechanism.
