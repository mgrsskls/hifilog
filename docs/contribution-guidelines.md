# Contribution guidelines

The contribution guidelines tell contributors how to add and edit brands, products, versions,
options, series and specifications. This document tells developers where the guidelines are and
how to change them. It uses Simplified Technical English (ASD-STE100).

## 1. Where the guidelines are

| Part                               | File                                                                                        |
| ---------------------------------- | ------------------------------------------------------------------------------------------- |
| Page `/contribute/guidelines`      | `app/views/contribute/guidelines.html.erb`                                                  |
| Chapters of the page               | `app/views/contribute/guidelines/_<chapter>.html.erb`                                       |
| Summaries above the forms          | `app/views/contribute/guidelines/_summary_<form>.html.erb`                                  |
| Box for the summaries              | `app/views/contribute/guidelines/_summary_box.html.erb`                                     |
| Markdown help (page and summaries) | `app/views/contribute/guidelines/_markdown_help.html.erb`                                   |
| Section ids and links              | `app/helpers/guidelines_helper.rb`                                                          |
| Styles                             | `app/assets/stylesheets/guidelines.css`, `.GuidelineLink` in `application/instructions.css` |

The forms use the summaries as follows:

| Form                        | Summary                                                   |
| --------------------------- | --------------------------------------------------------- |
| `brands/new`, `brands/edit` | `_summary_brand` (`edit: true` on the edit page)          |
| `products/_form`            | `_summary_product` (`edit:` is `include_comment`)         |
| `product_variants/_form`    | `_summary_product_variant` (`edit:` is `include_comment`) |
| `product_series/_form`      | `_summary_product_series`                                 |

The custom product form (`custom_products/_form`) has its own help text. Custom products are
private to one user, so the catalogue guidelines do not apply to them.

## 2. Rules for changes

1. **One place for each rule.** Write the full rule in the chapter partial. If the rule is
   important for a form, add a short version to the summary of that form and a link to the
   section. Do not write the full rule in a form.
2. **Section ids do not change.** Each section has an id from
   `GuidelinesHelper::GUIDELINE_SECTIONS` (the key, dasherized: `:brand_abbreviation` →
   `#brand-abbreviation`). Links in forms, emails and edit comments use these ids. Do not rename
   or remove a key. If a rule moves, keep its id on the new section.
3. **Numbers are for reading only.** The headings have numbers (3.7). You can change the numbers
   when you add a section. Do not use numbers in links.
4. **New section:** add the key to `GUIDELINE_SECTIONS` and set the id on the heading with
   `guideline_anchor(:key)`. `ContributeControllerTest` checks that the page has one element for
   each key.
5. **Changed rule:** add a line to `_changelog.html.erb`, newest first.
6. **Links from forms** open in a new tab (`target: "_blank"`). Thus the user does not lose the
   data in the form.

## 3. Performance

The page is static text. It does no database queries: `ContributeController` does not run
`set_category` for this action. The page is in a fragment cache. The cache key contains the
template digest, which includes the rendered partials, so a changed partial gets a new cache
entry automatically.

## 4. Decisions

| Topic                 | Decision                                                                                                                                                                         |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Place                 | One page in the Contribute section, with a table of contents. Short summaries stay on the forms.                                                                                 |
| Indexing              | The page can be indexed and is in the sitemap. The queue pages stay `noindex`.                                                                                                   |
| Comments              | The edit comment stays optional. The guidelines ask for the change and the source.                                                                                               |
| Price                 | The launch price in the currency in which it was published. No conversion, no inflation adjustment.                                                                              |
| Non-Latin names       | The name in Latin letters that the brand uses. The original script can go in the description.                                                                                    |
| Duplicates and errors | Contributors send an email to `info@hifilog.com` (`GuidelinesHelper#contact_email_link`; the link is written with HTML entities against spam bots). There is no report function. |
| Photos                | No photo rules yet.                                                                                                                                                              |
| Reference             | The structure follows the Discogs Database Guidelines: general rules first, then one chapter for each type of entry, a quick start and a changelog.                              |
