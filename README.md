# HiFi Log

Architecture reference for the domain model, read-only SQL projections, and how the main concepts relate. Not a setup or operations guide.

## Conceptual overview

The catalog is built around **brands** and **products**. A **product** is the canonical model for a piece of gear (name, brand, categories, base specs). A **product variant** is a smaller edition of that product under the same name (a special finish, a limited run, a regional model) that can override some fields while still inheriting the rest from the parent product. **A version whose specifications differ is a separate product, not a variant** — see [Product variant](#product-variant).

**Possessions** represent a user's relationship to something in the catalog (or to a user-defined **custom product**): ownership, photos, purchase details, and optional links into **setups**. They always point at real database rows (`products`, `product_variants`, or `custom_products`), not at the unified listing abstraction.

**Product items** are not a third kind of catalog entity. They are a **read-only database view** that flattens each product and each of its variants into one row each, so lists and filters can treat "a row in the catalog" uniformly while still knowing whether that row is the base product or a variant. A second view of the same shape, **contribute product items**, adds the completeness information the contribution queues sort and filter on.

```mermaid
flowchart TB
  Category --> SubCategory
  SubCategory --> Product
  SubCategory --> CustomAttribute
  Brand --> Product
  Product --> ProductVariant
  Product --> ProductOption
  ProductVariant --> ProductOption
  User --> Possession
  Possession --> Product
  Possession --> ProductVariant
  Possession --> CustomProduct
  Possession --> ProductOption
  Product --> Bookmark
  ProductVariant --> Bookmark
  Brand --> Bookmark
  Event --> Bookmark
  User --> BookmarkList
  BookmarkList --> Bookmark
  Setup --> SetupPossession --> Possession
  Product --> Note
  ProductVariant --> Note
  User --> EventAttendee --> Event
  User -->|follower| UserFollow -->|followed| User
  User -->|blocker| UserBlock -->|blocked| User
  subgraph readonly [Read-only projection]
    ProductItem["ProductItem (view)"]
    ContributeProductItem["ContributeProductItem (view)"]
    SearchResult["SearchResult (view)"]
  end
  Product -.-> ProductItem
  ProductVariant -.-> ProductItem
  Product -.-> ContributeProductItem
  ProductVariant -.-> ContributeProductItem
  Product -.-> SearchResult
  ProductVariant -.-> SearchResult
  Brand -.-> SearchResult
```

## Taxonomy

**`Category`** and **`SubCategory`** form the gear taxonomy. Products, brands, and custom products each link to many subcategories. **`CustomAttribute`** definitions are also scoped to subcategories so structured fields only apply where relevant. Category trees are cached for navigation.

## Brand

**`Brand`** is the manufacturer or label (identity, country, lifecycle dates, description, optional logo). Brands link to subcategories and have many products. Catalog edits are versioned (see [Auditing](#auditing)).

A brand carries three names, each with one job:

- **`name`** — canonical identity, written the way the manufacturer writes it ("Bang & Olufsen"). Unique, and the `friendly_id` slug source. Used for JSON-LD `name` and wherever the brand has to be identified unambiguously.
- **`abbreviation`** — optional short form the brand is known by that is **not** part of its name: "B&O" for "Bang & Olufsen". A `before_validation` clears anything already contained in `name`, so whatever survives is never already visible beside it and display sites need no repetition check. Catalog views expose it as `brand_abbreviation` so listings don't join.
- **`legal_name`** — optional registered company name ("Bang & Olufsen A/S"). Shown in the facts list on the brand page and filterable, but excluded from ranked search.

Two accessors decide which form is rendered where:

- **`Brand#display_name`** — `abbreviation` if there is one, otherwise `name`. This is the default. It is what product and variant titles use, what product slugs are built from, and what lists, breadcrumbs and nav links show wherever there is room for only one string.
- **`Brand#seo_name`** — `"B&O (Bang & Olufsen)"` when an abbreviation exists, otherwise `name`. Used for the brand page title; the brand page `<h1>` renders the same pair as markup rather than a string.

Where there is room for both — brands index rows, brand search results, the sitemap — the abbreviation has priority, followed by `name`.

Product titles and slugs are built from `Brand#display_name`, and nothing on `Product` notices a change to either brand column. So `Brand` has an `after_update` calling `Product.resync_slugs_for` whenever `name` **or** `abbreviation` changes (`brand_naming_changed?`); it re-slugs the brand's products and preserves the old slugs in `friendly_id_slugs` so they 301. Adding an abbreviation to an existing brand therefore moves every product URL under it, which is intended: the title moves too.

## Product

A product belongs to one brand, has many variants, options, possessions, notes, and can be bookmarked. It links to many subcategories.

The product holds shared identity: brand, name, slug, categorization, and shared metadata. Options declared directly on the product represent product-level specs, as distinct from options declared on a specific variant.

## Product variant

A variant belongs to one product and has its own options, possessions, and notes. Where a variant doesn't override a field, it falls back to the parent product's value. Variants can also be bookmarked directly, alongside products, brands, and events.

### A variant never has different specifications

This is the rule the custom attribute design rests on, so it is worth stating as a prohibition rather than a description. A variant is a **smaller edition under the same name** — a finish, a limited run, a regional model number. Anything whose measured behaviour differs, a Mk II or a second impedance, is **a separate product**.

Two consequences follow, and neither is a bug:

- `product_items` projects `products.custom_attributes` onto variant rows as well as product rows. That is correct by construction: a variant shares its parent's specs because it is not allowed to have others. Filtering by a spec therefore returns the product _and_ its variants, which is the right answer.
- Specs are excluded from a variant's completeness score, because there is nothing for a variant to fill in.

The rule is not enforced anywhere, and it fails quietly when broken: a variant added for a second impedance will display and be filtered under the parent's impedance, and nothing distinguishes that from a correct row. The contribution guidelines state the rule (`app/views/product_variants/_form.html.erb`); the catalogue does not check it.

Separating a Mk II into its own product also severs the link to what it replaced — there is no relationship between products today, so the two entries sit unrelated. That is the main pressure to bend the rule, and a lightweight succession link between products would relieve it without giving variants specs of their own.

## Catalog detail pages

**Product** and **ProductVariant** show pages share one orchestration path. For either entry type, the app loads:

- A **community image gallery** from possessions owned by users whose profiles allow catalog imagery (public always; logged-in-only when the viewer is signed in). Base-product pages use possessions with no variant; variant pages use that variant's possessions.
- **Contributors** from version history on the parent product.
- **Custom attributes** from the product (variants surface the parent's attribute set).
- When the viewer is signed in: their **possession**, **bookmark**, **note**, and **setups** scoped to that product or variant.

**`ProductCatalogShowService`** assembles this context for both show pages.

## Product option

`ProductOption` belongs to **either** a product **or** a variant (never both): one of the configurations that product is _sold in_ — colour, finish, cable length — each with its own optional `model_no`. Possessions may optionally reference one to record the configuration the user actually has.

### Option or custom attribute?

The two are easy to confuse, and the answer follows from who the value belongs to:

- A **custom attribute** is one value true of _every unit_ of the product. Weight, impedance, driver type. It describes the model, and the catalogue filters on it.
- A **product option** is one of several configurations the product is _sold in_, varying per purchased unit and usually carrying its own part number. Which one an owner has is recorded on their possession, not on the product.

So a cable's conductor material is an attribute and its length is an option: the same cable at 1 m and 2 m is one model in two configurations, and forcing length into an attribute would mean either one length per product or a separate product per length. The same test puts loudspeaker finish and cable termination on the option side.

Where a manufacturer genuinely sells the variants as distinct product lines rather than as configurations of one, a **`ProductVariant`** is the third answer — see [Product variant](#product-variant).

## Custom attributes (definitions vs values)

**Definitions** (`CustomAttribute`) are reusable fields tied to subcategories: label, input type, options, units, highlighted flag. Definitions are cached globally.

**Values** are stored directly on the product as a flexible set of key/value pairs, keyed by attribute label. Variants do not store their own values; wherever custom attributes are displayed for a variant, the parent product's values are shown instead. Filtering on catalog indexes uses the definitions applicable to the current category context. **`CustomProduct`** does not participate in this system at all.

### Naming a label

A label is a **disambiguator, not a namespace**. The subcategory join already scopes an attribute to where it applies, so a prefix that only restates the category buys nothing and costs something real: it forks one specification into two filter facets holding the same numbers in the same unit, which can then never be compared. The label names the measurement.

A prefix is only justified when two categories genuinely mean different things by the same word:

- **Different unit** — `headphone_sensitivity` (dB/mW) against `loudspeaker_sensitivity` (dB@1W/1m). Not comparable, so they must not share a range filter.
- **Different option set** — headphone enclosures (open / semi / closed) against speaker enclosures (sealed / ported / …).
- **Different question** — `cartridge_type` asks what a thing _is_, `supported_cartridge_types` asks what it _accepts_.

**Option values follow the same rule one level down.** They too live in one flat namespace (`custom_attributes.*`), so a key is shared when two attributes mean the same thing by it and prefixed when they merely share a word. `rca` and `xlr` are shared by `cable_interconnect_type`, `input_connectors` and `output_connectors`, because an RCA socket is an RCA socket everywhere and should be spelled — and renamed — in one place. `coaxial` and `optical`, by contrast, already mean a loudspeaker driver topology and a cartridge type, so the connector lists say `spdif_coaxial` and `toslink`: reusing them would tie a speaker's drivers to a DAC's inputs and let a relabelling of one corrupt the other.

**Which options apply is scoped per subcategory**, on the join row rather than the attribute: `input_connectors` is one question everywhere, but a phono stage answers it with RCA and XLR while a DAC answers it with USB, coaxial and TOSLINK. **`CustomAttributeSubCategory`** exists for that `custom_attributes_sub_categories.option_ids` column only; the HABTM associations still own "which attributes apply here" and are untouched. An empty array means all options, so leaving it unset is always safe, and the scope is read as a **union** across the product's subcategories rather than an intersection.

Scoping is **presentation-only, never a validation**: the product form renders every attribute up front and narrows the visible options client-side in `entity_form.js`, and an option already ticked is never hidden.

A corollary worth stating, because it decides how many attributes exist: **don't split an attribute along a distinction its option values already carry.** `input_connectors` covers analogue and digital together — `rca` is analogue and `toslink` is digital, and the value says so — where separate `analog_inputs`/`digital_inputs` would duplicate that in the schema, force a boundary ruling on every ambiguous connector, and produce subcategory sets that get it wrong. The in/out split does earn its place: `rca` sits on both sides, so direction is genuinely not recoverable from the value.

Where a prefix is warranted it comes from a closed list of **Category-level** words — `loudspeaker_`, `headphone_`, `turntable_`, `cartridge_`, `tonearm_`, `amplifier_`, `cable_`, `tube_`, `tape_` — never a subcategory name. Otherwise the bare term is used, chosen specifically enough that a future collision is unlikely (`bi_wiring`, not `wiring`).

### Labels and option values are i18n keys

Every surface that renders an attribute — product form, filter sidebar, spec list, the admin subcategory page — calls `t("custom_attribute_labels.#{label}")` **without a default**, so a label with no translation behind it does not degrade, it prints "translation missing" to the user. The same is true one level down for option values under `custom_attributes`, where a typo is worse still: products store the option _id_, so the broken key is invisible in the data and only surfaces on every product that chose it.

Definitions are admin-created data rows, so no test can enumerate what production holds; the only moment the two can be compared is the moment the row is written. `CustomAttribute` therefore validates both directions of that mapping. The practical consequence is a deploy order: **the translation ships before the attribute is created**, which is the same order `available_option_keys` already imposes by offering the admin a datalist of keys the locale file defines.

Units and inputs need the same translations, but `VALID_UNITS` and `VALID_INPUTS` are closed constants rather than data, so a test enumerates them instead of a validation.

**`inputs`** are named facets of one measurement sharing its unit: `w`/`h`/`l` are three dimensions in centimetres, `min`/`max` two ends of one range, `ohm_8`/`ohm_4` two load impedances an amplifier's power is quoted into. The filter applies its own min/max per facet, so all three shapes behave the same.

### Units and conversion

Two units on one definition mean _the same quantity in the other system_, and both the filter and the display path assume they can convert between them. **`CustomAttribute::UNIT_CONVERSIONS`** is the single table saying which pairs those are and by what factor; `UNIT_EQUIVALENTS` derives the reverse direction so a display can show both readings from either side. A definition may only offer two units when those two are a pair listed there, and a unit only belongs in the table once something genuinely converts to it.

Two units are not always a pair: `loudspeaker_sensitivity` offers dB@1W/1m and dB@2.83V/1m, which are two different measurements with no factor between them, and the display shows a single reading.

**Reads never convert, so values are normalised on write.** `Product` runs `CustomAttribute.normalize_units` before save, which makes "stored unit" and "canonical unit" the same thing everywhere downstream — filtering normalises a submitted range and then matches on the stored `unit` string. Normalisation sits on the model rather than in the product form so ActiveAdmin, `ProductConversionService` and the console are covered too. Values written before it existed were rewritten once by the `NormalizeStoredCustomAttributeUnits` migration.

The product form's unit radios declare **the unit the typed number is in**, not a display preference, so `entity_form.js` converts the displayed number whenever a radio is toggled — and merely relabels where the two units are not a convertible pair. Typed figures are read through `parseTypedNumber` rather than `parseFloat`, which infers the decimal-separator convention instead of silently truncating; the controller re-parses server-side as the net for when the JS has not run. (The filter sidebar's unit radios are not touched: those numbers are the visitor's own query, not a stored value.)

For the `option` and `options` input types, the definition's `options` is a JSON object mapping a **numeric id** to an **i18n key** under `custom_attributes` in the locale files. Products store the id, never the key — so a mislabelled option can be renamed without touching a single product row. The admin editor upholds that split: ids are assigned automatically, never reused, and are not editable, while the key is picked from a datalist of what the locale file already defines. Removing an option asks for confirmation and states how many products still point at it, counted in one aggregate query by **`CustomAttribute#option_usage_counts`**.

Exactly one shape of extra configuration applies per input type: `options` for `option`/`options`, `units` and `inputs` for `number`, neither for `boolean`. A `before_validation` clears whatever the current input type does not use, since the product form picks its control by inspecting those fields rather than `input_type`.

### Creating definitions in bulk

Definitions are data and **ActiveAdmin is where they are edited**. `rake custom_attributes:define` exists only for the thing clicking is bad at: bringing a tranche of them into being identically across environments, from a diff someone can review. It matches by label and updates, so a re-run reports no changes.

It is not a second source of truth. Two rules keep it from becoming one:

- **Options are declared as i18n keys, never ids**, so a re-run cannot renumber the value products actually store. Dropping a key raises rather than removing an option products still point at — that confirmation belongs in the admin form, which can show the counts.
- **Subcategories are referenced by slug, and an unresolved slug aborts the run.** A definition silently attached to fewer categories than intended is the failure this task exists to avoid.

## Catalog row views (`ProductItem`, `ContributeProductItem`)

`ProductItem` unions one row per product and one row per variant, distinguishing the two. Foreign keys elsewhere in the app still point at `Product` and `ProductVariant` directly — the view exists purely as a unified read surface, not as a new entity to relate to.

`ContributeProductItem` is a second view of the same shape, additionally carrying completeness information computed in SQL. Splitting it out keeps that extra computation off every catalog listing while letting the contribution queues sort and filter on completeness directly in the database.

Both models are read-only and share **`CatalogueProductRow`**, a concern covering brand and possession associations, list-thumbnail selection (base-product rows ignore variant-linked possessions), and image/subcategory-name preloading. `ProductItem` additionally supports name search and exposes the options that belong to each row. `ContributeProductItem` additionally exposes named gaps (missing release year, description, discontinued year, or specs) for the contribution queues to filter on, and carries its own variant-specific description so a variant lacking its own description doesn't disappear from that queue.

Use **Product** / **ProductVariant** to mutate data; use **ProductItem** for catalog listing and filters, **ContributeProductItem** for the contribution queues.

## Possession

A **user-owned instance** of catalog or custom gear, optionally tied to a `ProductOption`. Images attach to the possession. Product pages and base-product list thumbnails use possessions with no linked variant; variant surfaces use that variant's possessions.

**Setups** group possessions: `Setup` → `SetupPossession` → `Possession`. Setups are per-user, named, and may be **private** (affects public visibility and activity feed).

### Current vs previous collection

A flag separates the active collection from previous gear. Ownership spans are tracked as date ranges, and a timestamp records when an item moved from current to previous. Ownership changes drive corresponding **user activity** entries.

## Custom product

User-defined gear outside the shared catalog: categories, images, and exactly one linked **possession**. Does not use `Product`, `ProductVariant`, or `ProductItem`.

## Bookmark

Polymorphic saved reference (`Product`, `ProductVariant`, `Brand`, or `Event`)—not ownership. **`BookmarkList`** optionally groups bookmarks per user.

## Event

Dated occurrences with RSVPs via **`EventAttendee`**. Bookmarkable; included in global search projection for products/brands only, not events.

## Notes

Discussion text on a **product**, optionally scoped to a **variant** (one note per user per product/variant combination).

## Users, profiles, and dashboard

**`User`** accounts hold the collection, setups, bookmarks, notes, RSVPs, and profile media (avatar, decorative image).

**Profile visibility** (hidden, logged-in-only, visible) controls public discoverability and whether collection imagery from that user appears on catalog pages.

- **Public profile**: overview (collection preview, statistics, upcoming events, activity feed), full collection, previous gear, history, contributions.
- **Dashboard**: the signed-in owner's workspace—same domains plus a following-based activity feed, Community (following/followers), and settings pages for profile (visibility, images), notifications (follow emails, newsletter), and blocked users, alongside the Devise account form. The profile and notifications settings live under a dedicated **`Settings::`** namespace of controllers; blocked users has its own top-level controller.

## Following and blocking

**`UserFollow`** is a self-referential relationship (`follower` → `followed`). Creating one records an activity for the followed user and, if they've opted in to follow notifications, sends a notification email—at most once per follower/followed pair, so follow/unfollow toggling cannot spam the inbox. Unfollowing soft-hides the activity. Users cannot follow themselves or someone who blocks them; hidden profiles are excluded from follow feeds.

**`UserBlock`** (`blocker` → `blocked`) severs follow relationships in both directions on create. Blocks are not disclosed to the blocked user: the follow button stays visible and a follow attempt fails generically.

Follow notification emails support one-click unsubscribe, backed by **`FollowNotificationUnsubscribeService`** (signed token, parallel to the newsletter flow). The unsubscribe endpoints are public, token-authenticated controllers—**`FollowNotificationUnsubscribesController`** and **`NewsletterUnsubscribesController`**—that share the **`TokenUnsubscribe`** concern, separating a non-mutating confirmation step from the actual unsubscribe, and also supporting one-click unsubscribe requests initiated by mail clients. Because recipients may not be signed in, both are exempt from the privacy-policy gate.

## Authentication and admin

**Users** authenticate for the site (registration, confirmation, lockout). **Admin users** are a separate scope for back-office catalog management (ActiveAdmin). Community members can create and edit catalog entities; admins operate the full admin interface.

## Privacy policy

Published policy text has a **version** (requires re-acceptance) and a **content revision** (text-only updates). Users store which version they accepted and when. Sign-up requires acceptance; users on an outdated version must accept again or delete their account before using the app. Static/legal pages and account recovery remain available during that gate.

## User activity

Persisted **`UserActivity`** rows capture a verb, when it occurred, the affected catalog or social item, and enough metadata to render a feed entry without re-fetching it.

**Write path:** model callbacks feed into **`UserActivities::Recorder`** (with a **`PossessionSync`** helper reconciling ownership-related verbs).

**Read path:** **`UserActivityTimeline`** builds feed rows for the public overview and the owner dashboard. The dashboard feed is following-based: it merges the owner's activities with those of followed users (hidden profiles excluded) and shows the actor per row. A dedicated feed page paginates the same timeline at the database level.

Activity is generated across most of the domain: collection changes, custom products, setups (created, and made public/private), possessions added to or removed from a setup, event attendance, profile image changes, and new follows. Some verbs are recorded for auditing but excluded from public feeds; a small subset is only ever shown on the owner's own dashboard, never on public profiles.

The timeline applies a handful of presentation rules on top of raw chronological order: respecting setup privacy, avoiding redundant entries when a later event supersedes an earlier one, and grouping contiguous similar items.

A **backfill** task can rebuild activities from existing possessions, setups, RSVPs, and attachments where historical data allows.

## Search

**`SearchResult`** is a read-only view unioning products, variants, and brands with a unified name/slug shape for global search. **`ProductItem`** powers catalog browsing and category filters—separate concern from site-wide search.

## Auditing

**PaperTrail** versions **products**, **variants**, and **brands**. Per-record changelogs and a contributions summary show who edited the catalog over time.

## Completeness and contribution queues

Most catalog entries carry little more than a name and a brand, so _incomplete_ is the normal state rather than an error. The **`Completeness`** concern (included by `Brand`, `Product`, `ProductVariant`) describes how filled-in an entry is two ways: as **named gaps** for prompts on entry pages, and as a **0–100 score** for ordering the queues. Each including model weighs its own fields, roughly in proportion to how many surfaces a field feeds rather than by feel.

**Inapplicable fields don't count against the score** — they leave the denominator rather than scoring as missing, so nothing is permanently capped below 100% for something nobody can fix. **Highlighted custom attributes** are the app's notion of a "key spec" and are scored as one group; variants inherit the parent's attributes and cannot edit them, so specs are not part of a variant's own score.

**The score is computed twice**: once in Ruby for display, and once in SQL (a generated column on `brands`, an expression in the `contribute_product_items` view) so the database can sort and filter on it directly. The two are kept in sync by a dedicated test.

### Contribution queues

**`ContributeController`** is a task board for contributors: lists of entries each missing one specific, named gap. It is read-only and excluded from search indexing—every link leads into the existing brand or product edit forms.

Queues exist for brands with no products, brands missing a specific field, and products missing a specific field. All are optionally scoped to a `Category` and ordered by **descending completeness**—the nearly finished entries first, so a contributor is handed a small, finishable job instead of a blank form.

## Cross-cutting concerns

**Service objects** hold orchestration and multi-model queries that belong to neither a model nor a controller:

| Service                                                                        | Role                                                                                                                               |
| ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| **`ProductFilterService`**, **`BrandFilterService`**                           | Catalog and brand index filtering, sorting and name search, sharing `FilterableService`, `FilterConstants` and `RelevanceOrdering` |
| **`ProductCatalogShowService`**                                                | Product and variant show-page context                                                                                              |
| **`ProductConversionService`**                                                 | Converts a product into a variant of another product and back; never crosses brands                                                |
| **`CollectionStatusQuery`**                                                    | Owned / previously owned / bookmarked state for a set of ids, in bulk, for the client-side collection buttons                      |
| **`UserImagesQuery`**                                                          | Paginated community image feed across possessions and custom products                                                              |
| **`StatisticsService`**                                                        | Collection aggregates for dashboard and profile                                                                                    |
| **`CacheService`**                                                             | Taxonomy, counts and definition caches                                                                                             |
| **`SitemapBuilder`**                                                           | Sitemap pages and their `lastmod` timestamps                                                                                       |
| **`PossessionPresenterService`**                                               | Possession → presenter selection                                                                                                   |
| **`NewsletterUnsubscribeService`**, **`FollowNotificationUnsubscribeService`** | Signed-token unsubscribe flows                                                                                                     |
| **`UserActivities::Recorder`** / **`Backfill`**, **`UserActivityTimeline`**    | Activity write and read paths                                                                                                      |

Controllers keep their shared behaviour in concerns rather than a base class — notably `FriendlyFinder` (slug lookup plus 301 on an old slug), `FilterParamsBuilder`, `ProductCatalogShow`, `ProfileVisibility`, `EventListing` and `TokenUnsubscribe`.

**Caching** covers taxonomy menus, entity counts, custom attribute definitions, event counts, and some rendered legal or policy content.

**Attachments** (Active Storage): possession and custom-product image galleries; user avatar and decorative banner; brand logos. Purges on possessions and profile images can emit activity rows.

**App news** (`AppNews`) announcements can be dismissed per user, tracked by a join to `User`.

**Newsletter** issues are authored in ActiveAdmin and sent to users who opted in, with a test-send path and the signed-token unsubscribe flow above.

**Static pages** (`StaticController`) serve changelog, about, imprint, privacy policy and the calculators — currently the amplifier-to-headphone adapter resistor calculator. They touch no domain model.

**Statistics** aggregate a user's possessions (current vs previous, costs, duration, categories) for dashboard and profile summaries. In the UI this section is called **Insights**; the code keeps the statistics naming.

**Security:** Rack::Attack throttles on auth, catalog writes, bookmarks, notes, search and follow/block mutations; content security policy; Turnstile bot challenge on registration and password reset.

## Presenters

Presenters sit beside models and centralize display rules for templates.

| Presenter                                                               | Wraps                                                                |
| ----------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **`ItemPresenter`**                                                     | Base for gear with optional product/variant (usually via possession) |
| **`PossessionPresenter`**                                               | Current possession: prices, periods, gallery                         |
| **`PreviousPossessionPresenter`**                                       | Previous-collection possession                                       |
| **`ProductItemPresenter`**                                              | Catalog list row (paths, dates, list thumbnails)                     |
| **`BookmarkPresenter`**                                                 | Polymorphic bookmark target                                          |
| **`CustomProductPresenter`**                                            | Custom product with possession-like UI                               |
| **`SetupPossessionPresenter`**, **`CustomProduct*PossessionPresenter`** | Setup builder and related contexts                                   |
| **`ImagePresenter`**                                                    | Shared attachment presentation                                       |

**`PossessionPresenterService`** chooses among possession presenters by ownership state and custom-product linkage.

---

## Quick reference

| Concept                     | Mutable?  | Role                                                  |
| --------------------------- | --------- | ----------------------------------------------------- |
| `Category` / `SubCategory`  | Yes       | Taxonomy; scopes catalog and custom attributes        |
| `Brand`                     | Yes       | Manufacturer; products; bookmarks; search             |
| `Product`                   | Yes       | Shared catalog identity                               |
| `ProductVariant`            | Yes       | Variant-specific overrides                            |
| `ProductItem`               | No (view) | Unified catalog rows                                  |
| `ContributeProductItem`     | No (view) | Same rows plus completeness/specs, for contribute     |
| `SearchResult`              | No (view) | Global search rows                                    |
| `Possession`                | Yes       | Ownership, photos, setups; current vs previous        |
| `Setup`                     | Yes       | Named public/private gear groupings                   |
| `CustomProduct`             | Yes       | Off-catalog user gear                                 |
| `Bookmark` / `BookmarkList` | Yes       | Saved references; optional lists                      |
| `Event` / `EventAttendee`   | Yes       | Occurrences and RSVPs                                 |
| `ProductOption`             | Yes       | Spec lines on product or variant                      |
| `CustomAttribute`           | Yes       | Field definitions; values on `Product`                |
| `UserActivity`              | Yes       | Social/history feed                                   |
| `UserFollow`                | Yes       | Follower → followed relationship; drives feed & email |
| `UserBlock`                 | Yes       | Blocker → blocked; severs follows both ways           |
| `User`                      | Yes       | Account, visibility, policy acceptance, profile media |
