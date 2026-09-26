# frozen_string_literal: true

# Write the fields that an imported product may have to a JSON file.
#
# The importer outside the application must not have its own idea of what a
# product is. A sub category that is added in the admin, or an option that is
# added to a custom attribute, changes what an importer is allowed to write.
# If the importer keeps its own copy of that list, the two lists become
# different, and the difference shows only when an import fails or, worse,
# writes a value that no form can show.
#
# Therefore the database is the source, and this task is the only way the
# importer learns the shape. Run it before an import run:
#
#   bin/rails import:schema > tools/brand_importer/schema/product_schema.json
#
# The output holds no product data and no identifiers that change between
# environments: sub categories are named by slug, attributes by label, options
# by their i18n key. The same file is therefore valid in development and in
# production, and a difference between two runs is a real change of the model.
namespace :import do
  desc 'Write the brands to crawl as CSV (slug, name, website)'
  # Only brands that have a website: the importer reads brand sites, and a brand
  # without one has nothing to read. The count that this prints is therefore also
  # the answer to "how much of the catalogue can this reach at all".
  task brands: :environment do
    require 'csv'

    scope = Brand.where.not(website: [nil, '']).order(:name)
    scope = scope.where(discontinued: [false, nil]) if ENV['ACTIVE_ONLY'] == 'true'

    puts 'slug,name,website'
    scope.find_each do |brand|
      puts CSV.generate_line([brand.slug, brand.name, brand.website]).chomp
    end
    warn "#{scope.count} brand(s) with a website"
  end

  desc 'Write the importable product schema (sub categories and custom attributes) as JSON'
  task schema: :environment do
    sub_categories = SubCategory.includes(:category).order(:id).map do |sub_category|
      {
        slug: sub_category.slug,
        identifier: sub_category.identifier,
        name: sub_category.name,
        category: sub_category.category.name
      }
    end

    attributes = CustomAttribute.order(:label).map do |attribute|
      scopes = CustomAttributeSubCategory
               .where(custom_attribute_id: attribute.id)
               .includes(:sub_category)
               .to_h { |join| [join.sub_category.slug, join.option_ids] }

      {
        label: attribute.label,
        # The extractor reads a specification sheet written for people, so it needs the
        # words a person sees, not only the key. Both travel together: the key is what an
        # import writes, the translation is what makes the key understandable.
        name: I18n.t("custom_attribute_labels.#{attribute.label}", default: attribute.label),
        input_type: attribute.input_type,
        units: attribute.units,
        inputs: attribute.inputs,
        # The conditions this specification may be quoted under, each with the words a person
        # reads on a sheet -- "±3 dB", "At 1% THD" -- because that string is what the extractor
        # has to recognise in the source text. The key is what an import writes.
        qualifiers: attribute.qualifiers.to_h do |qualifier|
          [qualifier, I18n.t("custom_attribute_qualifiers.#{qualifier}", default: qualifier)]
        end,
        # { option id => i18n key }, with the English label beside each key for the same
        # reason. The id is the part a product stores.
        options: (attribute.options || {}).transform_values do |key|
          { key: key, name: I18n.t("custom_attributes.#{key}", default: key) }
        end,
        sub_categories: scopes.keys.sort,
        option_scopes: scopes.compact_blank
      }
    end

    puts JSON.pretty_generate(
      generated_at: Time.current.iso8601,
      sub_categories: sub_categories,
      custom_attributes: attributes
    )
  end
end
