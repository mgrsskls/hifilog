# Custom attributes

Custom attributes are the fields for the technical values of a product: weight, impedance, driver type and
so on. This document describes definitions and values, the naming rules, translations, units,
qualifiers, the options, the display order and the bulk definition task. It uses Simplified Technical English (ASD-STE100).

For the difference between an attribute and a product option, see
[catalog-model.md](catalog-model.md#61-option-or-custom-attribute).

## 1. Definitions and values

**Definitions** (`CustomAttribute`) are reusable fields. They are attached to sub categories. A
definition has a label, an input type, options, units, qualifiers, a "highlighted" flag, a
display group and a display position (see [8. Display order](#8-display-order)). The application
caches all definitions. The cache key contains the column names of the table, so after a migration
the application does not use definitions that were cached with the old columns.

**Values** are stored on the product as a set of key/value pairs. The key is the label of the
attribute. Variants do not store values. Where the application shows attributes for a variant, it
shows the values of the parent product. The filters on catalog pages use the definitions that
apply to the current category. `CustomProduct` does not use custom attributes.

**Highlighted** attributes are the "key specs" of a sub category. They are part of the
completeness score (see [completeness.md](completeness.md)).

## 2. Naming a label

A label **identifies a measurement**. It is not a namespace. The sub category join already limits
an attribute to the sub categories where it applies. A prefix that only repeats the category has
no function. It also causes a problem: it makes two filter facets for one measurement, with the
same numbers in the same unit, and the two facets can then not be compared.

Use a prefix only when two categories use the same word for different things:

- **Different unit**: `headphone_sensitivity` (dB/mW) and `loudspeaker_sensitivity` (dB, with the
  drive reference in a qualifier). These values cannot be compared, so they must not share a range
  filter.
- **Different option set**: headphone enclosures (open, semi, closed) and loudspeaker enclosures
  (sealed, ported, …).
- **Different question**: `cartridge_type` asks what a thing _is_. `supported_cartridge_types`
  asks what it _accepts_.

A prefix comes from a closed list of **category-level** words: `loudspeaker_`, `headphone_`,
`turntable_`, `cartridge_`, `tonearm_`, `amplifier_`, `cable_`, `tube_`, `tape_`. Never use a sub
category name. Without a prefix, use a term that is specific enough to prevent a collision later
(`bi_wiring`, not `wiring`).

### 2.1 Option values

The same rule applies to option values. All option values are in one namespace
(`custom_attributes.*`). Two attributes share a key when they mean the same thing by it. They use
a prefix when they only share a word.

- `rca` and `xlr` are shared by `cable_interconnect_type`, `input_connectors` and
  `output_connectors`. An RCA socket is the same everywhere, so it has one spelling and one place
  to rename it.
- `coaxial` and `optical` already mean a loudspeaker driver topology and a cartridge type. Thus,
  the connector lists use `spdif_coaxial` and `toslink`. A shared key would connect the drivers of
  a loudspeaker to the inputs of a DAC, and a new label for one would make the other incorrect.

### 2.2 Do not split an attribute along its values

Do not make two attributes for a distinction that the option values already show.
`input_connectors` covers analogue and digital connectors: `rca` is analogue and `toslink` is
digital. Separate `analog_inputs` and `digital_inputs` attributes would repeat this in the schema,
need a decision for each unclear connector, and give incorrect sub category sets. The split into
inputs and outputs is necessary: `rca` is on the two sides, so the value does not show the
direction.

### 2.3 Options for each sub category

**The options that apply are set for each sub category**, on the join row and not on the
attribute. `input_connectors` is one question everywhere, but a phono stage answers it with RCA and
XLR and a DAC answers it with USB, coaxial and TOSLINK.

- `CustomAttributeSubCategory` exists only for the column
  `custom_attributes_sub_categories.option_ids`. The HABTM associations still control which
  attributes apply to a sub category.
- An empty array means all options. Thus, an empty value is always safe.
- The application reads the scope as a **union** over the sub categories of the product, not as
  an intersection.

The scope **only changes the display**. It is not a validation. The product form shows all
attributes and `entity_form.js` hides the options that do not apply. It never hides an option that
is already selected.

## 3. Labels and option values are i18n keys

Each view that shows an attribute (product form, filter sidebar, specification list, admin sub
category page) calls `t("custom_attribute_labels.#{label}")` **without a default**. When the
translation is missing, the user sees "translation missing". The same applies to option values
under `custom_attributes`. A typo there is worse: products store the option _id_, so the incorrect
key is not visible in the data. It shows on each product that uses the option.

Admins create definitions as data rows. Thus, no test can know which definitions production has.
The only time to compare the definition with the locale file is when the row is written. For this
reason, `CustomAttribute` validates the two directions of the mapping.

This gives a deploy order: **deploy the translation before you create the attribute.**
`available_option_keys` has the same order: it gives the admin a datalist of the keys that the
locale file has.

`VALID_UNITS`, `VALID_INPUTS` and `DISPLAY_GROUPS` also need translations. They are constants, not
data, so a test checks them.

**`inputs`** are named facets of one measurement with one unit:

- `w`, `h`, `l`: three dimensions in centimetres.
- `min`, `max`: the two ends of a range.
- `ohm_8`, `ohm_4`: the two load impedances for the output power of an amplifier.

The filter applies its own minimum and maximum for each facet. Thus, the three shapes work in the
same way.

## 4. Two units

Two units on one definition are two systems for the same quantity, for example `kg` and `lb`, or
`cm` and `in`.

- **`CustomAttribute::UNIT_CONVERSIONS`** is the only table of the unit pairs and their factors.
- `UNIT_EQUIVALENTS` gives the reverse direction.
- The units of a definition are all units that its sub categories can offer, for example kg, lb
  and g for weight. They must convert to each other. Each sub category offers a selection of them
  (see [4.5 Units per sub category](#45-units-per-sub-category)). A sub category that offers the
  two units of a pair (`CustomAttribute#unit_pair?`) gets the two rows of the product form. Add a
  unit to the table only when a conversion to it is necessary.

Two readings that no factor relates are not two units. `loudspeaker_sensitivity` had dB@1W/1m and
dB@2.83V/1m as units until qualifiers existed. It now has one unit, dB, and the drive reference is
a qualifier (see §5). Put a second reading of one figure in `qualifiers`, never in `units`.

### 4.1 Stored figures

An entry stores **the figures that the source states, in the unit of the source**. The application
does not convert a figure when it writes it.

```jsonc
"weight": { "value": 15, "unit": "kg" }
"weight": { "value": 33, "unit": "lb" }
"weight": { "value": 15, "unit": "kg", "second": { "value": 33, "unit": "lb" } }
"dimensions": {
  "value": { "w": 43, "h": 12, "l": 35 }, "unit": "cm",
  "second": { "value": { "w": 17, "h": 4.7, "l": 13.8 }, "unit": "in" }
}
```

- `value` and `unit` hold one stated figure. `second` holds the figure in the other unit of the
  pair, when the source states it too.
- When the source states both figures, the metric figure is in `value` and the imperial figure is
  in `second`. Thus, the same two figures always have the same shape, and the changelog does not
  show a change when a contributor enters the same figures in a different order.
- An entry with one figure keeps it in its unit, also when that unit is imperial.
- A qualifier applies to the entry, so there is one qualifier for the two figures.

`Product` calls `CustomAttribute.prune_unsupported_keys` and then `CustomAttribute.order_figures`
before save:

- `prune_unsupported_keys` removes a `second` when the definition does not offer the other unit of
  `unit`, when its unit is not that unit, or when it holds no figure.
- `order_figures` moves the metric figure into `value`. When an entry has a `second` but no
  `value`, it moves `second` into `value`. It removes an entry that holds no figure after these
  steps. Such an entry shows "n/a" and counts as filled for the completeness score.

These steps are in the model and not in the product form. Thus, ActiveAdmin, `ImportPromotion`,
`ProductConversionService` and the console write the same shape.

Before figures were stored in the unit of the source, the application converted each figure into
the metric unit on save. The migration `RestoreStatedImperialFigures` put back the imperial figures
that were converted in this way. It finds them because the conversion is an exact multiplication:
14.96850821 kg is exactly 33 lb. It restores an entry when both conditions are true:

- The metric figure has more decimals than a brand states in that unit: more than three for `kg`,
  more than one for `cm`, more than two for `m`.
- Converted back, it gives an imperial figure with at most two decimals.

The first condition protects a stated figure that is by chance an exact conversion: 127 cm is
exactly 50 in, but it has no decimals. The threshold depends on the unit because the factors
differ: every pound figure becomes a long number in kilograms, but a whole inch figure becomes a
centimetre figure with two decimals at most (17 in is 43.18 cm).

An entry without a unit reads in the first unit of the definition, on the product page and in the
product form.

### 4.2 Display

`CustomAttributeReading` gives the reading of an entry. All display sites use it: the product page,
the product card, the changelog, the admin activity list and the import candidate view.

- A stated figure is shown as stored.
- When the definition offers both units of the pair and the entry states one figure only, the
  other figure follows, converted.
- A converted figure is rounded to the significant figures of the stated figure, but to no fewer
  than two (`CustomAttribute::MIN_SIGNIFICANT_FIGURES`). Thus, a conversion is not more precise than
  its source.

| Stored              | Shown             |
| ------------------- | ----------------- |
| 15 kg               | 15 kg / 33 lb     |
| 33 lb               | 33 lb / 15 kg     |
| 15 kg, second 34 lb | 15 kg / 34 lb     |
| 1.35 kg             | 1.35 kg / 2.98 lb |
| 0.2 kg              | 0.2 kg / 0.44 lb  |
| 15 cm               | 15 cm / 5.9 in    |

The significant figures come from the stored number. Zeros after the decimal point are lost when a
figure is stored, so "15.0" counts two significant figures.

The product card has space for one figure. It shows the metric figure, stated or converted. Thus,
a list never shows "15 kg" next to "33 lb".

The changelog and the admin activity list show the second figure too. Without it, a change of the
second figure alone shows the same text before and after the change.

### 4.3 Filtering

The visitor selects a unit and a range. The filter compares each product with its figure in the
selected unit:

1. The stated figure in that unit, from `value` or `second`.
2. If there is none, the figure in the other unit, converted and rounded like on the product page.

Thus, the product page and the filter agree: "15 kg" shows as "33 lb" and the filter "up to 33 lb"
finds it. `ProductFilterService#converted_figure_sql` does the rounding in SQL. It must count the
significant figures in the same way as `CustomAttribute.significant_figures`. A test compares the
two.

A range needs a unit. The unit radio buttons in the filter become required when the visitor types
a range. The server ignores a range without a unit, because neither unit is a safe guess. This
applies to old links and to changed URLs.

The comparison is a calculation for each row, like all range filters. The GIN index on
`products.custom_attributes` cannot serve it. An expression index for each attribute and unit is
possible later.

### 4.4 Product form

For a sub category that offers a unit pair, the product form shows one row for each unit, the
metric row first. The contributor fills in the rows for the figures that the source states: one
row or both. The form has no unit radio buttons for these sub categories, and it converts nothing.

When both rows hold a figure, `entity_form.js` shows a warning if the two figures cannot describe
the same measurement. The rule is in `CustomAttribute.figures_agree?`:

- A figure stands for a range: half of its last decimal place in each direction. "0.7 lb" is 0.65
  to 0.75 lb, which is 0.295 to 0.340 kg.
- The two figures agree when their ranges overlap after conversion. Thus, "0.3 kg" agrees with
  "0.7 lb", although the two differ by 5.8 %.

A fixed percentage cannot do this: it is too strict for figures with few digits and too lenient for
figures with many digits. The contributor can save with the warning, because the figures of a
brand sometimes disagree.

`parseTypedNumber` reads the typed numbers, not `parseFloat`. It finds the decimal separator and
does not cut the number. The controller parses the number again on the server, for the case when
the JavaScript did not run.

### 4.5 Units per sub category

The values of one attribute can have a very different scale in two sub categories. A loudspeaker
weighs many kilograms, but a cartridge weighs a few grams. Each sub category thus offers its own
selection of the units of the definition. The product form of a cartridge asks for grams, and the
contributor does not select a unit.

- The units are on the link between the attribute and the sub category (`units` on
  `CustomAttributeSubCategory`). They are a selection of the units of the definition, in the
  order of the definition.
- An admin ticks them in ActiveAdmin, in the table "Units per category" of the attribute. The
  table has a row for each category ticked in the form and a column for each unit ticked above.
  The row "All categories" ticks a unit in all rows.
- **There is no default.** Each sub category needs at least one unit, or the form refuses the save
  (`CustomAttribute#sub_category_units_must_be_chosen`). The admin decides which combination makes
  sense. One unit or one pair is best: with other combinations, the contributor must select a unit.
- When an admin removes a unit from the definition, the unit also leaves each sub category. If a
  sub category then has no unit, the form refuses the save.
- The rule applies to the admin form only. Other paths write links without units: the Sub
  Category admin, a HABTM assignment in the console. A link without units falls back to all units
  of the definition (`CustomAttribute#units_in`). The bulk definition task gives all units of the
  definition to each sub category without units (`CustomAttribute#tick_all_units_where_missing`).
- `CustomAttribute::UNIT_SCALES` holds the factors between two sizes of one system, for example g
  and kg. `CustomAttribute.conversion_factor` uses this table and `UNIT_CONVERSIONS` together.
  Thus, g also converts to lb.
- A scale is not a pair. An entry in grams holds one figure, and the product page shows no
  converted figure for it. An entry in kilograms shows the figure in pounds when the definition
  offers lb (`CustomAttribute#partner_offered?`), also for a sub category that offers kg only.

The migration `FillUnitsOfCustomAttributesSubCategories` gave each existing link the units of its
attribute, so that nothing changed for contributors.

The stored figure follows [4.1 Stored figures](#41-stored-figures): an entry in grams stores
`{ "value": 6.5, "unit": "g" }`. When a sub category offers one unit only and it is not the only
unit of the definition, the product form posts the unit too. Without the unit, the entry would read
in the first unit of the definition.

**Product form.** The form renders the fields of the attribute one time for each group of sub
categories with the same units (`CustomAttribute#unit_variants`). `entity_form.js` shows the group
of the first ticked sub category, in menu order, and disables the fields of the other groups. Thus,
a product in two sub categories with different units has one set of fields. When the stored figure
is in a unit that the group does not offer, the form shows it converted
(`CustomAttribute#entry_in_own_units`). For example, a cartridge weight that was entered as
0.0065 kg shows as 6.5 g, and a save stores 6.5 g.

**Filter.** A list page offers the units of all its sub categories
(`CustomAttribute#filter_units_for`). A category page with loudspeakers and cartridges offers kg,
lb and g. The filter compares each product in the selected unit, as in
[4.3 Filtering](#43-filtering), and converts from each other unit of the definition. A page with
one unit, for example the cartridges page, compares in that unit and shows no unit choice.

**Convert stored figures.** A change of the units of a sub category does not change the stored
figures. A headphone weight stored as 0.35 kg still shows as "0.35 kg / 0.77 lb" on the product
page, and only the product form shows 350 g. `bin/rails custom_attributes:convert_units` converts
each entry whose unit is not a unit of the product's sub category (`SubCategoryUnitConversion`):

- The units come from the first sub category in menu order (`CustomAttribute#units_for`), as in the
  product form.
- The entry gets the first of these units, converted and rounded like in the product form. A second
  figure goes, because the new unit has no pair.
- The task writes without PaperTrail, because the measurement does not change. It touches the
  product to clear the caches.

Without `APPLY=1`, the task only prints what it would change. `LABEL=weight` limits it to one
attribute. It is safe to run two times.

```sh
bin/rails custom_attributes:convert_units LABEL=weight          # dry run
bin/rails custom_attributes:convert_units LABEL=weight APPLY=1  # write
```

`bin/rails import:schema` exports the units of each sub category as `unit_scopes`.

## 5. Qualifiers

A **qualifier** is the condition under which a number was measured: ±3 dB for a frequency
response, 1% THD for an output power. It is a third axis of a `number` attribute, beside the unit
and the inputs. `CustomAttribute::VALID_QUALIFIERS` holds the closed set, and a definition declares
the subset it offers in `qualifiers`.

A qualifier is **always optional**. Many sources state no condition. An absent `qualifier` key
means "not stated", and the application never writes a default: an assumed condition is invented
data. The completeness score does not count the qualifier.

### 5.1 Which axis to use

The three axes do different work, and the product form is what shows the difference:

| Axis         | Work                             | Example                            |
| ------------ | -------------------------------- | ---------------------------------- |
| `units`      | Changes the scale of the number  | `kg` and `lb`                      |
| `inputs`     | Gives one number for each facet  | `w` / `h` / `l`, `ohm_8` / `ohm_4` |
| `qualifiers` | Says how the number was measured | ±3 dB, at 1% THD                   |

`inputs` is a **request**: a small, fixed set of operating points that the catalog asks for in each
case, and the form shows one field for each. A qualifier is a **description**: the condition of the
one figure that the source gives.

To decide, ask if the catalog wants to collect each combination:

- Width, height and length: yes, for each product. Use `inputs`.
- Power into 8 Ω and into 4 Ω: yes, for each amplifier. Use `inputs`.
- Power at 0.1%, at 1% and at 10% THD: no. Most sources give one figure, so fields for all three
  collect empty values. Use a qualifier.

Do not use the test "can both values be true at the same time". A brand can give power at 0.1% THD
**and** at 1% THD, and both figures are true, but the catalog must not ask each amplifier for three
figures that almost no source gives. A nominal impedance and a minimum impedance are different:
the catalog wants both for each loudspeaker, and they are correctly two attributes.

### 5.2 One dimension for each definition

An entry holds one `qualifier`. Therefore the `qualifiers` of a definition must exclude each other.
A list that mixes two dimensions cannot be stored: "1% THD" and "both channels driven" are both
true of one figure. Declare one dimension, and leave a second dimension out of scope.

A source that gives the same specification under two conditions loses one of the two figures,
because a product has one entry for each attribute. The contributor records the figure at the
tighter condition — see [contribution-guidelines.md](contribution-guidelines.md).

### 5.3 The write path

`unit` and `qualifier` are strings that the caller chooses, and nothing in the database constrains
them. `CustomAttribute.prune_unsupported_keys` therefore removes a blank value and a value that the
definition does not declare. `Product` calls it in `before_save`, before `order_figures` (§4.1).

"Declares none" means different things for the two keys, so they are treated differently:

- A definition with **no units** says nothing about units, and the filter says nothing either: it
  applies a unit predicate only when the definition has some. A stored unit is therefore kept. To
  remove it would accomplish nothing.
- A definition with **no qualifiers** asks no question about the condition, so a stored condition is
  not an answer. It is removed. It would otherwise still show on the product page, because the
  display reads the entry and not the definition.

It is on the model and not in the products controller, for the same reason as `order_figures`:
every write path lands here — the product form, ActiveAdmin, `ImportPromotion`,
`ProductConversionService` and the console. An import candidate is the case that makes this
necessary rather than tidy: it holds the specs the extractor wrote, `ImportPromotion` copies them
verbatim, and a candidate from before a definition changed still carries the old unit.

A blank qualifier must not be stored. It is neither a condition nor absent, so `? 'qualifier'`
would report a condition that is not there and every reader would need a third case.

### 5.4 Filtering

The qualifier is a facet that the visitor selects, with two states. Nothing selected adds no
condition to the query. Equality would give almost no results: a value cannot be changed into a
condition that nobody measured, and the coverage is low. One or more selected
conditions give an `OR` of `@>` containment tests, which the GIN index on
`products.custom_attributes` can use.

A selected condition means "measured this way", so a figure with no condition is not a match. The
facet has no "not stated" option: a visitor who wants the looser answer selects nothing. The
product form does have a "Not stated" option, because a contributor must be able to clear a
condition.

For the reasons, the sub category lists and the later "or better" filter, see
[custom-attribute-qualifiers.md](custom-attribute-qualifiers.md).

## 6. Options of `option` and `options` attributes

For the input types `option` and `options`, the `options` of the definition is a JSON object. It
maps a **numeric id** to an **i18n key** under `custom_attributes`. Products store the id, never
the key. Thus, you can rename an option without a change to a product row.

The admin editor keeps this split:

- The editor gives the ids automatically. It never uses an id again, and you cannot edit an id.
- You select the key from a datalist of the keys that the locale file has.
- When you remove an option, the editor asks for a confirmation. It shows how many products use
  the option. **`CustomAttribute#option_usage_counts`** counts them in one aggregate query.

Each input type uses one type of configuration: `options` for `option` and `options`, `units` and
`inputs` for `number`, and nothing for `boolean`. A `before_validation` clears the fields that the
input type does not use. This is necessary because the product form selects its control from these
fields, not from `input_type`.

## 7. Create definitions in bulk

Definitions are data. **Edit them in ActiveAdmin.** The task `rake custom_attributes:define` is
only for one job: to create a set of definitions in the same way in all environments, from a file
that a person can review. It finds definitions by label and updates them. When you run it again,
it reports no changes.

The task is not a second source of truth. Two rules make sure of this:

- **Options are declared as i18n keys, never as ids.** Thus, a second run cannot give new numbers
  to the values that products store. When a key is removed from the file, the task stops with an
  error. It does not remove an option that products use. That confirmation belongs in the admin
  form, which can show the counts.
- **Sub categories are identified by slug. When a slug is not found, the run stops.** The task
  must not attach a definition to fewer sub categories than intended.

## 8. Display order

The product page, the product form and the filter sidebar show custom attributes in the same
order. The order does not come from the values of the product. It comes from two fields of the
definition:

- **`display_group`**: one of `CustomAttribute::DISPLAY_GROUPS`. The order of this list is the
  order of the groups. The groups are `design`, `performance`, `connectivity` and `physical`.
- **`display_position`**: an integer. It sets the order in the group. A lower number shows first.
  Use gaps (10, 20, 30), so that you can add an attribute between two others without a change to
  the others.

When two definitions have the same group and position, the label sets the order. Both fields are
mandatory. Set them in ActiveAdmin.

`CustomAttribute.sort_for_display` sorts a list of definitions. `CustomAttribute.group_for_display`
also splits the list into groups. It does not return a group that has no definitions. The sort
runs in Ruby, not in SQL, because the order of the groups is in code. All callers have the
definitions in memory already, so the sort does not add a query.

The places show the groups differently:

| Place                                                | Group headings                                                                             |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Product page, product variant page, similar products | Yes. A group without a value on the product is not shown.                                  |
| Product form                                         | Yes. A group is hidden when none of its attributes applies to the selected sub categories. |
| Filter sidebar                                       | No. Only the order.                                                                        |

### 8.1 Add a group

1. Add the key to `CustomAttribute::DISPLAY_GROUPS`, at the position where the group must show.
2. Add the translation under `custom_attribute_groups` in the locale file. A test makes sure that
   each group has a translation.
3. Deploy. Then move the attributes to the new group in ActiveAdmin.

When you remove a group, move its attributes to a different group first. The validation refuses
a definition with a group that is not in the list.

The bulk definition task (see [7. Create definitions in bulk](#7-create-definitions-in-bulk)) also
declares the group and the position. When you run it, it sets these two fields again.
