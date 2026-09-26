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

## 4. Units and conversion

Two units on one definition mean _the same quantity in the other system_. The filter and the
display convert between the two.

- **`CustomAttribute::UNIT_CONVERSIONS`** is the only table of the unit pairs and their factors.
- `UNIT_EQUIVALENTS` gives the reverse direction. Thus, the display can show the two values from
  each side.
- A definition can have two units only when the pair is in the table. Add a unit to the table only
  when a conversion to it is necessary.

Two readings that no factor relates are not two units. `loudspeaker_sensitivity` had dB@1W/1m and
dB@2.83V/1m as units until qualifiers existed. It now has one unit, dB, and the drive reference is
a qualifier (see §5). Put a second reading of one figure in `qualifiers`, never in `units`.

The display and `entity_form.js` still test that a pair is in the table before they convert. That
test is a guard, not a special case for one attribute: where two units do not convert, the display
shows one value only and the form relabels the number instead of converting it.

### 4.1 Values are normalised on write

**Reads do not convert. Thus, writes normalise the values.** `Product` calls
`CustomAttribute.normalize_units` before save. After that, the stored unit is always the canonical
unit. The filter normalises the submitted range and then compares it with the stored `unit`
string. The normalisation is in the model and not in the product form. Thus, ActiveAdmin,
`ProductConversionService` and the console also normalise. The migration
`NormalizeStoredCustomAttributeUnits` changed the older values one time.

### 4.2 Units in the product form

The unit radio buttons in the product form set **the unit of the typed number**. They are not a
display preference. When the user selects a different unit, `entity_form.js` converts the number.
When the two units are not a pair, it only changes the label.

`parseTypedNumber` reads the typed numbers, not `parseFloat`. It finds the decimal separator and
does not cut the number. The controller parses the number again on the server, for the case when
the JavaScript did not run. The unit radio buttons of the filter sidebar are different: those
numbers are the query of the visitor, not a stored value.

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
definition does not declare. `Product` calls it in `before_save`, beside `normalize_units` and
before it, so a unit the definition does not offer is dropped and not used as the basis of a
conversion.

"Declares none" means different things for the two keys, so they are treated differently:

- A definition with **no units** says nothing about units, and the filter says nothing either: it
  applies a unit predicate only when the definition has some. A stored unit is therefore kept. To
  remove it would accomplish nothing and would stop the normalisation, which needs the unit to
  convert from.
- A definition with **no qualifiers** asks no question about the condition, so a stored condition is
  not an answer. It is removed. It would otherwise still show on the product page, because the
  display reads the entry and not the definition.

It is on the model and not in the products controller, for the same reason as the normalisation:
every write path lands here — the product form, ActiveAdmin, `ImportPromotion`,
`ProductConversionService` and the console. An import candidate is the case that makes this
necessary rather than tidy: it holds the specs the extractor wrote, `ImportPromotion` copies them
verbatim, and a candidate from before a definition changed still carries the old unit.

A blank qualifier must not be stored. It is neither a condition nor absent, so `? 'qualifier'`
would report a condition that is not there and every reader would need a third case.

### 5.4 Filtering

The qualifier is a facet that the visitor selects, with two states. Nothing selected adds no
condition to the query. Equality, as for the unit, would give almost no results: a value cannot be
normalised into a condition that nobody measured, and the coverage is low. One or more selected
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
