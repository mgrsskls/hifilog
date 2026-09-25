# Related Products

The **"Related Products"** block on product and variant pages lists companions with which an entry
is compatible. This document describes the implementation. The authoring source of the graph, the
edge lists and the reasons for them are in [pairing-graph.md](pairing-graph.md). This document uses
Simplified Technical English (ASD-STE100).

The block is a read-only projection over the catalog. It has no tables of its own.

The block has three separate stages:

1. **Gate**: can the application show this candidate at all?
2. **Score**: how good is this suggestion?
3. **Assemble**: what does the block contain?

## 1. The graph

**`RelatedProducts::Graph`** is a set of Ruby constants that a person writes.

- A **role** groups the sub categories that have the same position in a signal chain
  (`power_amp`, `headphone`, `cable_phono`). Each sub category has exactly one role.
- **Edges have a direction.** An edge on role A to role B means "B can show on the page of A". The
  reverse is a separate declaration. For example, a power cable belongs on an amplifier page, but an
  amplifier does not belong on a power cable page.
- **The order of the declarations is the priority.**
- Roles that only receive edges (cables, racks, isolation, power conditioning) declare no edges of
  their own.

Roles exist only in the code. The database does not store them. The only cached part is the list of
sub category ids (`CacheService.sub_category_ids_for`).

### 1.1 Roles select, sub categories group

A role collects candidates from all its sub categories. But the group that the reader sees has the
label and the link of the sub category that its items are in. Each role shows a maximum of one
group: the sub category of its best candidate.

Roles have no page. For example, a heading for `integrated` ("Integrated Amplifiers & Receivers")
could only link to the full Amplifiers category, which also has phono stages and tuners. When the
application groups by sub category, each heading shows exactly what the group lists and links to a
real index. The cost: the other sub categories of a role do not show on that page.

### 1.2 References are protected

The graph is Ruby constants. Thus, the database cannot enforce its references. The models refuse
the changes that would break them:

- The `identifier` of a `SubCategory` cannot change (see
  [catalog-model.md](catalog-model.md#2-taxonomy)).
- A `CustomAttribute` cannot be renamed or deleted while a gate names it.
- An option key cannot be removed while a gate names it.

`rake related_products:check` finds the problems that a guard cannot see. The most important
problem is a sub category with no role.

### 1.3 Consumables

The graph declares which roles are **consumables**: valves, cartridges, headphone cables. For these
roles, a discontinued product is normal and often better. The ordering rules read this from the
graph, not from a separate list.

## 2. Gates

An edge can depend on custom attributes. There are four shapes of gate:

| Shape              | Meaning                                              | Example                                                                                                                                   |
| ------------------ | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| **source**         | The source product must have a value.                | Power tubes show on an amplifier only when `amplifier_type` is tube or hybrid.                                                            |
| **target**         | The candidates are limited.                          | A step-up transformer page lists only `cartridge_type = mc`.                                                                              |
| **cross match**    | The source value must intersect the candidate value. | A cartridge shows on a phono stage only when the stage supports its type.                                                                 |
| **specialisation** | The value changes _which_ edges exist.               | A passive loudspeaker wants a power amplifier and a speaker cable. An active one wants a preamplifier, an interconnect and a power cable. |

The gates declare option values as **i18n keys**. The query changes them to stored option ids. Thus,
a new name for an option cannot break a gate. `ProductVariant` has no attributes of its own. On a
variant page, each gate reads the parent product.

### 2.1 Missing values

There are two different failure modes:

- An attribute that **applies but has no value** closes the gate. The edge does not show, because
  "no value" is not the same as "known not to match".
- An attribute that is **not attached to that sub category** does not apply. The edge shows without
  a gate, because nobody asked the question.

`Completeness` uses the same rule: a field that does not apply leaves the denominator and does not
count as missing (see [completeness.md](completeness.md)).

When few products have values for the gate attributes, most pages do not show the block.
Thus, these attributes are among the most valuable contribution targets.

### 2.2 Disabled edges

Some edges are disabled, because no attribute can express their gate:

- Headphone, digital and speaker cables have no connector or termination attribute on either side.
- Interconnects have a connector attribute. When few products have a value, the attribute
  closes the gate on each role that it applies to, and leaves the gate open on the one role that it
  does not apply to. These edges stay off until enough products have a value.
- A DAC or streamer that feeds a power amplifier or an active loudspeaker needs volume control. No
  attribute records volume control.

An edge without its gate is not a weaker suggestion. It is advice to buy something that does not
connect.

## 3. Ordering

`discontinued` is not a compatibility fact and never filters. A large part of the catalog is
discontinued.
`products.discontinued` is `null: false`, so `false` means "in production" or "nobody has said".

The candidates are ordered by:

1. **Completeness**.
2. **Not discontinued**. This applies only when the source product is current. Consumable roles do
   not use this rule, because new old stock is the desirable end of those markets.
3. A **stable hash of the source and the candidate**. Thus, one brand with good data does not lead
   every page.

Two rules apply to the full set. They are in Ruby, not in the `ORDER BY`:

- On edges where the components are designed as systems, exactly one candidate of the same brand
  moves to the top.
- When a product in production exists, the block shows at least one.

When a discontinued base product has a current variant, the block shows that variant. This change
occurs before the ordering, so the row gets the rank of what the reader sees.

Co-occurrence in setups and possessions is the signal that the ordering needs but does not use yet.
[pairing-graph.md](pairing-graph.md) §7 gives the intended weights and the reason why it is not
active.

## 4. Implementation

- **`RelatedProducts.for`** is the entry point. `ProductCatalogShowService` calls it.
- **`Resolver`** changes the source product into ordered targets with resolved gates.
- **`Query`** gets the candidates, selects the strongest sub category of each target, and assembles
  the groups in one round trip. It is a `UNION ALL` of one bounded subquery for each target over
  `contribute_product_items`, which has the completeness expression. The gates become SQL from
  `Resolver::Gate`. They are not encoded as JSONB.

**Nothing is cached.** A cached block would need invalidation for each edit to each product in a
target sub category.

`rake related_products:check` checks the graph against a real catalog:

- Each sub category has a role.
- Each gate names an attribute that exists.
- Each option key is still available.

The fixtures are too small for these checks. A sub category that an admin adds in production is not
visible to a test. Thus, run the task against production data.
