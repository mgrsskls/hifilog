# frozen_string_literal: true

# Moving the decisions between environments, without moving the data.
#
# An import produces two very different things. Products are catalogue content
# and belong in one place, which is production. Mappings are decisions -- "this
# shop's word means this sub category" -- and they are worth keeping for ever,
# they are small, and they are the same in every environment.
#
# So the mappings travel as a file, and the file is committed. This is the same
# rule that `custom_attributes:define` already follows: the admin is where a
# decision is made, and a reviewable file is how it reaches the other
# environments identically.
#
#   rake import:mappings:export   the decisions in this database -> the file
#   rake import:mappings:load     the file -> the decisions in this database
#
# Brands and sub categories are named by slug, never by id: ids differ between
# development and production, slugs do not. A slug that does not resolve is
# reported and skipped rather than guessed at, because a mapping attached to the
# wrong sub category would classify hundreds of products wrongly and silently.
namespace :import do
  namespace :mappings do
    DEFAULT_MAPPINGS_FILE = 'db/import_category_mappings.yml'

    desc 'Write the category mappings of this database to a file for review and for other environments'
    task :export, [:file] => :environment do |_task, args|
      require 'yaml'

      path = Rails.root.join(args[:file] || DEFAULT_MAPPINGS_FILE)
      rows = ImportCategoryMapping.includes(:brand).map do |mapping|
        slugs = mapping.sub_categories.pluck(:slug)
        {
          'brand' => mapping.brand&.slug,
          'source_category' => mapping.source_category.to_s,
          # Always the plural key, even for one: a word that means two things
          # is normal, and one shape for the file is easier to read than two.
          'sub_categories' => slugs.presence,
          'out_of_scope' => mapping.out_of_scope,
          # nil is left out by compact, which is right: no statement.
          'discontinued' => mapping.discontinued
        }.compact
      end
      # Sorted, so that the file changes only when a decision changes. An
      # unordered dump would show a different diff on every export and nobody
      # would read it.
      rows.sort_by! { |row| [row['brand'].to_s, row['source_category'].downcase] }

      File.write(path, rows.to_yaml)
      puts "#{rows.size} mapping(s) written to #{path}"
    end

    desc 'Apply the category mappings from the file to this database'
    task :load, [:file] => :environment do |_task, args|
      require 'yaml'

      path = Rails.root.join(args[:file] || DEFAULT_MAPPINGS_FILE)
      abort "no such file: #{path}" unless File.exist?(path)

      rows = YAML.safe_load_file(path) || []
      brands = Brand.pluck(:slug, :id).to_h
      sub_categories = SubCategory.pluck(:slug, :id).to_h

      created = 0
      updated = 0
      skipped = []

      rows.each do |row|
        brand_slug = row['brand']
        # `sub_category` (one) is still read, because the first file written by
        # hand used it. `sub_categories` (a list) is what is written now.
        wanted_slugs = Array(row['sub_categories'] || row['sub_category']).compact_blank

        if brand_slug.present? && !brands.key?(brand_slug)
          skipped << [row, "no brand #{brand_slug.inspect}"]
          next
        end
        missing = wanted_slugs.reject { |slug| sub_categories.key?(slug) }
        if missing.any?
          skipped << [row, "no sub category #{missing.map(&:inspect).join(', ')}"]
          next
        end

        mapping = ImportCategoryMapping.find_or_initialize_by(
          brand_id: brand_slug.present? ? brands[brand_slug] : nil,
          source_category: row['source_category']
        )
        was_new = mapping.new_record?
        mapping.sub_category_ids = wanted_slugs.map { |slug| sub_categories[slug] }
        mapping.out_of_scope = row.fetch('out_of_scope', false)
        mapping.discontinued = row['discontinued']

        if mapping.changed? || was_new
          if mapping.save
            was_new ? created += 1 : updated += 1
          else
            skipped << [row, mapping.errors.full_messages.to_sentence]
          end
        end
      end

      puts "#{created} mapping(s) created, #{updated} updated, " \
           "#{rows.size - created - updated - skipped.size} unchanged."
      if skipped.any?
        puts "\n#{skipped.size} row(s) skipped:"
        skipped.first(20).each do |row, reason|
          puts format('  %-40<word>s %<reason>s',
                      word: "#{row['brand']}/#{row['source_category']}".truncate(38), reason: reason)
        end
      end
      puts "\nRun `rake import:map` to apply them to the candidates that are waiting."
    end
  end

  desc 'Empty the staging tables (never in production)'
  task :reset, [:confirm] => :environment do |_task, args|
    # A pilot in development ends with the staging tables emptied, so that the
    # rehearsal cannot be mistaken later for the real review. Products that were
    # already written stay: they are catalogue content and are not this task's
    # business.
    abort 'refusing to empty staging in production' if Rails.env.production?
    unless args[:confirm] == 'yes'
      abort "This deletes every import candidate and batch in #{Rails.env}. " \
            'Run `rake import:reset[yes]` if that is what you want.'
    end

    candidates = ImportCandidate.count
    batches = ImportBatch.count
    ImportCandidate.delete_all
    ImportBatch.delete_all
    puts "#{candidates} candidate(s) and #{batches} batch(es) deleted. " \
         'Mappings and products are untouched.'
  end
end
