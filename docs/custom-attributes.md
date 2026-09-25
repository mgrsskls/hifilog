# Custom attributes

Custom attributes are the fields for the technical values of a product: weight, impedance, driver type and
so on. This document describes definitions and values, the naming rules, translations, units and
the bulk definition task. It uses Simplified Technical English (ASD-STE100).

For the difference between an attribute and a product option, see
[catalog-model.md](catalog-model.md#61-option-or-custom-attribute).

## 1. Definitions and values

**Definitions** (`CustomAttribute`) are reusable fields. They are attached to sub categories. A
definition has a label, an input type, options, units and a "highlighted" flag. The application
caches all definitions.

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

- **Different unit**: `headphone_sensitivity` (dB/mW) and `loudspeaker_sensitivity`
  (dB@1W/1m). These values cannot be compared, so they must not share a range filter.
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

`VALID_UNITS` and `VALID_INPUTS` also need translations. They are constants, not data, so a test
checks them.

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

Two units are not always a pair. `loudspeaker_sensitivity` has dB@1W/1m and dB@2.83V/1m. These are
two different measurements with no factor, and the display shows one value only.

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

## 5. Options of `option` and `options` attributes

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

## 6. Create definitions in bulk

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
